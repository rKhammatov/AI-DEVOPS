Быстрый старт
Если вы впервые запускаете Hermes Agent, создайте каталог данных на хосте и запустите контейнер в интерактивном режиме, чтобы воспользоваться мастером настройки:

mkdir -p ~/.hermes
docker run -it --rm \
  -v ~/.hermes:/opt/data \
  nousresearch/hermes-agent setup

После этого вы перейдете в мастер настройки, который запросит у вас ключи API и запишет их в ~/.hermes/.env. Это нужно сделать только один раз. На этом этапе настоятельно рекомендуется настроить систему чатов для работы шлюза.


```bash
docker compose -f docker-compose.yml up -d
docker compose -f docker-compose.yml logs -f
docker compose -f docker-compose.yml restart
docker compose -f docker-compose.yml down
```
Чтобы открыть интерактивный сеанс чата с работающим каталогом данных:

docker run -it --rm \
  -v ~/.hermes:/opt/data \
  nousresearch/hermes-agent

Или, если вы уже открыли терминал в работающем контейнере (например, через Docker Desktop), просто выполните команду:

/opt/hermes/.venv/bin/

docker run -it --rm nousresearch/hermes-agent:latest version     # Verify version


docker run -d \
  --name hermes \
  --restart unless-stopped \
  -v ~/.hermes:/opt/data \
  -p 8642:8642 \
  -p 9119:9119 \
  -e HERMES_DASHBOARD=1 \
  -e HERMES_TUI_DIR=/opt/hermes/ui-tui \
  -e API_SERVER_ENABLED=true \
  -e API_SERVER_HOST=0.0.0.0 \
  -e API_SERVER_KEY=123456789 \
  -e API_SERVER_CORS_ORIGINS='*' \
  -e HERMES_DASHBOARD_TUI=1 \
  nousresearch/hermes-agent gateway run
