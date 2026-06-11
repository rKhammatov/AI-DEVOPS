# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Что это

Self-hosted AI-стек для Ubuntu VPS (16 ГБ RAM, без GPU). Семь независимых docker-сервисов, у каждого — своя папка с `docker-compose.yml` и `README.md`:

- **Ollama** (`:11434`) — локальный LLM-сервер. Именованный том `ollama_models`.
- **MCP-server** (`:5042`, `:5043`) — инструменты пользователя. Готовый образ `docker.io/rhammatov/mock-service-mcp:latest` (ASP.NET Core). Сейчас bind-mount-ит `/home/orion/devops/mcp/dev` → `/app/database/` и подключён к `ai-net` (соседи находят его по DNS-имени `mcp-server-dev`). Блок `build:` закомментирован — работает на готовом образе.
- **OpenClaw** (`openclaw-devops/`, `:18789` gateway + `:18790` bridge) — агент №1. Два сервиса в одном compose: `openclaw-gateway` (демон) и `openclaw-cli` (интерактивный CLI, `depends_on` gateway). Образ **собирается** (`build: .`) из отдельно клонируемого исходника.
- **Hermes** (`:9119`, `:8642`) — агент №2 от Nous Research, запускается командой `gateway run` и требует первоначального `setup`-визарда (см. `hermes/README.md`).
- **Ouroboros** (`:8765`) — веб-агент. Образ **собирается** (`build: ./ouroboros-desktop`) из отдельно клонируемого репозитория `joi-lab/ouroboros-desktop`.
- **Dozzle** (`:9999`) — веб-просмотрщик логов всех контейнеров хоста. Читает `/var/run/docker.sock:ro`, поэтому видит контейнеры независимо от сети. Защищён basic-auth из своего `.env`.
- **Postgres** (`:5432`) — реляционная БД. Официальный образ `postgres:17`, именованный том `postgres_pg_data`. В `ai-net` — соседи ходят по `postgres:5432`. Креды из `.env` (`POSTGRES_USER/PASSWORD/DB`).

Папка **`nginx-devops/`** — пока пустой каталог-заготовка (нет ни `docker-compose.yml`, ни конфигов). Если в нём появится reverse-proxy, это изменит инвариант №3 («без reverse-proxy») — уточни у пользователя замысел, прежде чем что-то наполнять.

Конфигурация хранится здесь (compose-файлы, `.env.example`, markdown). Исходники приложений сюда **не коммитятся**: OpenClaw и Ouroboros клонируются отдельными репозиториями в подпапки, которые игнорируются git (см. `.gitignore`), и собираются локально. Любые изменения в этом репо = правка YAML/конфигов/markdown.

## Архитектурные инварианты

1. **Общая внешняя сеть `ai-net`** — объявлена в каждом compose как `external: true`. Создаётся один раз вручную: `docker network create ai-net`. Без неё `up` падает. Контейнеры в сети обращаются друг к другу по имени сервиса: `http://ollama:11434`. Имя для DNS — это **имя сервиса в compose** (у MCP это `mcp-server-dev`, не `mcp-server`).
2. **Каждый сервис управляется отдельно** — семь независимых `docker-compose.yml`, никакого общего top-level compose. Падение/обновление одного не трогает остальных.
3. **Порты пробрасываются на `0.0.0.0`** — сервисы доступны из интернета напрямую, без reverse-proxy. Безопасность обеспечивается токенами в `.env`/`environment` каждого сервиса и UFW. (Dozzle защищён basic-auth; Hermes сейчас с захардкоженным `API_SERVER_KEY` прямо в compose.)
4. **`.env` рядом с compose** — у MCP, OpenClaw, Hermes, Dozzle есть `.env`/`.env.example`; реальный `.env` не коммитится (см. `.gitignore`). `docker compose restart` НЕ перечитывает `.env` — нужен `up -d`.
5. **Тома** — именованные `ollama_models` и `postgres_pg_data`, плюс bind-тома агентов (`hermes`: `~/.hermes:/opt/data`; `ouroboros`: `./workspace`, `./state`) переживают `down`. `down -v` стирает именованные тома (для Ollama = потеря моделей, для Postgres = потеря БД).

## Жёсткие правила проекта

- **Bash-скрипты — только для утилит, не для управления сервисами.** Допустимы небольшие вспомогательные скрипты (напр. `postgres/backup.sh` — дамп БД). По-прежнему НЕ создаём скрипты-обёртки над жизненным циклом сервисов (`bootstrap.sh`, `update.sh`) и `Makefile`/`justfile`/`taskfile` — запуск/обновление сервисов остаётся прямыми командами `docker compose`.
- **Все комментарии в compose-файлах, `.env` и README — на русском.** Английский только для имён сервисов, переменных, ключей YAML.
- **Комментируй каждую нетривиальную строку** в `docker-compose.yml`: зачем она и что сломается, если убрать.
- **Не выполнять `docker` команды** из этого окружения — здесь нет VPS, только редактирование файлов.

## Команды, которые реально нужны

```bash
# Предусловие — один раз на VPS
docker network create ai-net

# Поднять конкретный сервис
docker compose -f ollama/docker-compose.yml          up -d
docker compose -f mcp-server/docker-compose.yml      up -d
docker compose -f openclaw-devops/docker-compose.yml up -d   # собирается из исходника
docker compose -f hermes/docker-compose.yml          up -d
docker compose -f ouroboros/docker-compose.yml       up -d --build   # собирается из исходника
docker compose -f dozzle/docker-compose.yml          up -d
docker compose -f postgres/docker-compose.yml        up -d

# Применить правки в compose / .env
docker compose -f <папка>/docker-compose.yml up -d
# (restart не перечитывает .env — нужен up -d)

# Логи / отладка
docker compose -f <папка>/docker-compose.yml logs -f
docker exec -it <имя> sh

# Скачать модель в Ollama
docker exec -it ollama ollama pull llama3.1:8b-instruct-q4_K_M
```

Полный набор сценариев (бэкапы, cleanup, дебаг сети, типовые проблемы) — в корневом `README.md`. Если пользователь спрашивает «как сделать X», сначала проверь README — там скорее всего уже есть готовый рецепт.

## Когда работаешь с этим репо

- **Структура жёсткая** — пользователь явно просил не переименовывать папки, не добавлять/убирать сервисы, не «улучшать» структуру.
- **Image vs build** — MCP на готовом образе (`image:`, блок `build:` закомментирован). OpenClaw (`build: .`) и Ouroboros (`build: ./ouroboros-desktop`) собираются из локально клонируемого исходника. Hermes и Dozzle — на готовых образах. Не теряй комментарии при переключении image↔build.
- **OpenClaw/Ouroboros: исходник клонируется отдельно** — рабочий compose OpenClaw живёт в `openclaw-devops/openclaw/` (клон, см. его README про `mv docker-compose.yml`), Ouroboros собирается из `ouroboros/ouroboros-desktop/`. Обе подпапки в `.gitignore` — в основной репо не коммитятся.
- **Образы агентов пользователь сверяет сам** — теги (`ghcr.io/openclaw/openclaw:*`, `nousresearch/hermes-agent:latest`) сверяются с актуальной документацией. Не «исправляй» без явной просьбы.
- **Hermes требует setup-визард** — первый запуск через `docker run -it ... nousresearch/hermes-agent setup`, который пишет ключи в `~/.hermes/.env`. Compose-сервис (`gateway run`) стартует уже после.
- **Dozzle: правка `.env` (логин/пароль) применяется только через `up -d`** — `restart` не перечитает basic-auth.
