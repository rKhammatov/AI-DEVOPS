# OpenClaw

Агент, ходящий в Ollama и MCP. Web UI на :18789.

Установка

git clone https://github.com/openclaw/openclaw.git



cd openclaw

mv docker-compose.yml docker-compose.yml.bak
mv ../docker-compose.yml docker-compose.yml



export OPENCLAW_IMAGE="ghcr.io/openclaw/openclaw:latest"

#export OPENCLAW_IMAGE="ghcr.io/openclaw/openclaw:2026.04.26"

./scripts/docker/setup.sh


## Команды

```bash
docker compose -f openclaw/docker-compose.yml up -d
docker compose -f openclaw/docker-compose.yml logs -f
docker compose -f openclaw/docker-compose.yml restart
docker compose -f openclaw/docker-compose.yml down
```

## Тома

- `openclaw_config` — память агента, сессии (бэкапить регулярно).
- `./workspace/` — рабочие файлы агента, видны на хосте.
- `./config/` — конфиги, монтируются read-only.
