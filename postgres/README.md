# PostgreSQL

Реляционная БД для сервисов стека. Порт `5432`.
Соседи в сети `ai-net` подключаются по DNS-имени `postgres` (хост = имя сервиса).

## Первый запуск

```bash
cp postgres/.env.example postgres/.env
# открой .env и задай POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
docker compose -f postgres/docker-compose.yml up -d
```

## Команды

```bash
docker compose -f postgres/docker-compose.yml up -d                 # запуск
docker compose -f postgres/docker-compose.yml down                  # остановка (том остаётся)
docker compose -f postgres/docker-compose.yml logs -f               # логи
docker compose -f postgres/docker-compose.yml pull                  # обновить образ
docker exec -it postgres psql -U appuser -d appdb                   # psql внутри контейнера
```

## Подключение из других контейнеров

Из любого сервиса в сети `ai-net` (агенты, MCP):

```
postgresql://appuser:ПАРОЛЬ@postgres:5432/appdb
```

Хост — имя сервиса `postgres`, работает только внутри `ai-net`. С самого хоста/интернета —
`postgresql://appuser:ПАРОЛЬ@<IP_VPS>:5432/appdb`.

## Применить правки

| Что изменил | Команда         |
|-------------|-----------------|
| `.env`      | `up -d`         |
| `compose`   | `up -d`         |
| Образ       | `pull && up -d` |

`restart` НЕ перечитывает `.env` — нужен `up -d`.

## Данные и бэкап

Данные лежат в именованном томе `postgres_pg_data`. Переживает `down`, **стирается** `down -v`.

Физически том хранится на хосте в служебном каталоге Docker (на Linux):

```
/var/lib/docker/volumes/postgres_pg_data/_data
```

Внутри контейнера он примонтирован в `/var/lib/postgresql/data`. Точный путь и параметры тома:

```bash
docker volume inspect postgres_pg_data          # поле "Mountpoint" — путь на хосте
docker volume ls | grep postgres                # список томов
```

Не редактируй файлы в этом каталоге вручную — Postgres должен быть остановлен, иначе повредишь
кластер. Для бэкапа используй `pg_dump` (ниже).

```bash
# Дамп БД в файл на хосте
docker exec postgres pg_dump -U appuser appdb > dump.sql

# Восстановление из дампа
cat dump.sql | docker exec -i postgres psql -U appuser -d appdb
```

Или готовым скриптом (читает креды из `.env`, кладёт сжатый дамп в текущую папку):

```bash
chmod +x postgres/backup.sh   # один раз
./postgres/backup.sh          # создаст appdb_ГГГГ-ММ-ДД_ЧЧММСС.dump
```

## Безопасность

Порт `5432` проброшен на `0.0.0.0` — БД доступна из интернета, защита только паролем.

- Задай **сильный** `POSTGRES_PASSWORD`.
- Открой порт в firewall: `sudo ufw allow 5432/tcp`.
- Чтобы скрыть БД от интернета, замени в `docker-compose.yml`:
  ```yaml
  - "127.0.0.1:5432:5432"   # доступ только с самого VPS / через ssh-туннель
  ```
