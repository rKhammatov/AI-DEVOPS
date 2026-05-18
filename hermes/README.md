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

docker run -d \
  --name hermes \
  --restart unless-stopped \
  -v ./.hermes:/opt/data \
  -p 8642:8642 \
  -p 9119:9119 \
  -e HERMES_DASHBOARD=1 \
  -e API_SERVER_ENABLED=true \
  -e API_SERVER_HOST=0.0.0.0 \
  -e API_SERVER_KEY=123456789 \
  -e API_SERVER_CORS_ORIGINS='*' \
  nousresearch/hermes-agent gateway run