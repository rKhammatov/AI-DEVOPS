# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Что это

Self-hosted AI-стек для Ubuntu VPS (16 ГБ RAM, без GPU). Четыре независимых docker-сервиса:

- **Ollama** (`:11434`) — локальный LLM-сервер.
- **MCP-server** (`:5042`, `:5043`) — инструменты пользователя. Сейчас — готовый образ `docker.io/rhammatov/mock-service-mcp:latest` (ASP.NET Core). MVP-режим bind-mount-ит только `./skills` → `/app/skills`.
- **OpenClaw** (`:18789`) — агент №1.
- **Hermes** (`:9119`, `:8642`) — агент №2 от Nous Research, запускается командой `gateway run` и требует первоначального `setup`-визарда (см. `hermes/README.md`).

Здесь **нет** исходного кода приложений — только compose-файлы, конфиги и markdown-документация. Любые изменения = правка YAML/конфигов.

## Архитектурные инварианты

1. **Общая внешняя сеть `ai-net`** — объявлена в каждом compose как `external: true`. Создаётся один раз вручную: `docker network create ai-net`. Без неё `up` падает. Контейнеры обращаются друг к другу по имени сервиса: `http://ollama:11434`, `http://mcp-server:5042`.
2. **Каждый сервис управляется отдельно** — четыре независимых `docker-compose.yml`, никакого общего top-level compose. Падение/обновление одного не трогает остальных.
3. **Порты пробрасываются на `0.0.0.0`** — сервисы доступны из интернета напрямую, без reverse-proxy. Безопасность обеспечивается токенами в `.env` каждого сервиса и UFW.
4. **`.env` рядом с compose** — у MCP, OpenClaw, Hermes есть `.env.example`; реальный `.env` не коммитится (см. `.gitignore`). `docker compose restart` НЕ перечитывает `.env` — нужен `up -d`.
5. **Тома** — `ollama_models` (именованный) и `hermes_data` (bind `./.hermes`) переживают `down`. `down -v` стирает их (для Ollama = потеря всех скачанных моделей).

## Жёсткие правила проекта

- **Никаких bash-скриптов** — ни `bootstrap.sh`, `update.sh`, ни `Makefile`/`justfile`/`taskfile`. Только `docker compose` команды напрямую и markdown.
- **Все комментарии в compose-файлах, `.env` и README — на русском.** Английский только для имён сервисов, переменных, ключей YAML.
- **Комментируй каждую нетривиальную строку** в `docker-compose.yml`: зачем она и что сломается, если убрать.
- **Не выполнять `docker` команды** из этого окружения — здесь нет VPS, только редактирование файлов.

## Команды, которые реально нужны

```bash
# Предусловие — один раз на VPS
docker network create ai-net

# Поднять конкретный сервис
docker compose -f ollama/docker-compose.yml     up -d
docker compose -f mcp-server/docker-compose.yml up -d
docker compose -f openclaw/docker-compose.yml   up -d
docker compose -f hermes/docker-compose.yml     up -d

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
- **Image vs build** — MCP сейчас на готовом образе (`image:`), блок `build:` закомментирован. Если переключаешь обратно на сборку, не теряй комментарии.
- **OpenClaw и Hermes — placeholder-образы** — пути в `image:` (`ghcr.io/openclaw/openclaw:latest`, `ghcr.io/nousresearch/hermes-agent:latest`) пользователь сам сверяет с актуальной документацией. Не ходи их «исправлять» без явной просьбы.
- **Hermes требует setup-визард** — первый запуск делается через `docker run -it ... nousresearch/hermes-agent setup`, который пишет ключи в `~/.hermes/.env`. Compose-сервис стартует уже после.
- **`.gitignore` игнорирует `openlaw-devops/openclaw/`** — там, по-видимому, у пользователя живёт исходник/сабмодуль OpenClaw отдельно.
