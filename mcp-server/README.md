# MCP Server (MVP)


## Команды

```bash
docker compose -f mcp-server/docker-compose.yml up -d --build   # запуск с пересборкой
docker compose -f mcp-server/docker-compose.yml restart         # мгновенный рестарт (для правок кода)
docker compose -f mcp-server/docker-compose.yml logs -f         # логи
docker compose -f mcp-server/docker-compose.yml down            # остановка
```

## Применить правки

|Что изменил         |Команда                         |
|--------------------|--------------------------------|
|Код (с hot-reload)  |ничего                          |
|Код (без hot-reload)|`restart`                       |
|Зависимости         |`up -d --build --force-recreate`|
|`.env`              |`up -d`                         |
