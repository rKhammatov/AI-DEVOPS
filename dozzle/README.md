# Dozzle

Веб-интерфейс для просмотра логов всех Docker-контейнеров в реальном времени.
Порт: `9999`. Доступен по `http://<IP_VPS>:9999`.

## Первый запуск

```bash
cp dozzle/.env.example dozzle/.env
# открой .env и задай DOZZLE_USERNAME и DOZZLE_PASSWORD
docker compose -f dozzle/docker-compose.yml up -d
```

## Команды

```bash
docker compose -f dozzle/docker-compose.yml up -d     # запуск
docker compose -f dozzle/docker-compose.yml down      # остановка
docker compose -f dozzle/docker-compose.yml pull      # обновить образ
docker compose -f dozzle/docker-compose.yml logs -f   # логи самого Dozzle
```

## Применить правки

| Что изменил | Команда        |
|-------------|----------------|
| `.env`      | `up -d`        |
| `compose`   | `up -d`        |
| Образ       | `pull && up -d`|

## Доступ

Dozzle читает логи через `/var/run/docker.sock` — видит **все** контейнеры на хосте,
независимо от того, в какой сети они находятся.

Чтобы скрыть интерфейс от интернета, замени в `docker-compose.yml`:
```yaml
- "127.0.0.1:9999:8080"   # доступен только через ssh-туннель
```
