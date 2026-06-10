#!/usr/bin/env bash
# Бэкап БД Postgres через pg_dump. Дамп сохраняется в ТЕКУЩУЮ папку (откуда запущен скрипт).
# Запуск:
#   chmod +x postgres/backup.sh      # один раз
#   ./postgres/backup.sh             # дамп ляжет в текущий каталог
set -euo pipefail

# Каталог самого скрипта — там же лежит .env с кредами БД.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Подтягиваем POSTGRES_USER / POSTGRES_DB из .env рядом со скриптом (если есть).
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a              # экспортировать всё, что объявлено ниже
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
  set +a
fi

# Значения по умолчанию, если .env не задал переменные.
: "${POSTGRES_USER:=appuser}"
: "${POSTGRES_DB:=appdb}"

CONTAINER="postgres"
# Имя файла с датой/временем, чтобы бэкапы не перезатирались.
OUT="./${POSTGRES_DB}_$(date +%Y-%m-%d_%H%M%S).dump"

# -Fc — сжатый custom-формат (компактнее .sql, восстановление через pg_restore).
# Postgres не останавливаем — pg_dump делает согласованный снимок на лету.
docker exec "$CONTAINER" pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB" > "$OUT"

echo "Готово: $OUT"
echo "Восстановить: cat \"$OUT\" | docker exec -i $CONTAINER pg_restore -U $POSTGRES_USER -d $POSTGRES_DB --clean"
