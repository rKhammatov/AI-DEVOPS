# AI Stack

Self-hosted стек из четырёх независимых docker-сервисов:
**Ollama** (LLM), **MCP-server** (мои инструменты, MVP),
**OpenClaw** и **Hermes** (агенты). Связаны общей docker-сетью,
каждый управляется своим `docker-compose.yml`.


- **Отдельные compose-файлы** — каждый сервис стартует/обновляется
  независимо. Падение MCP не трогает Ollama и агентов.
- **Общая сеть `ai-net`** — контейнеры находят друг друга по имени:
  `http://ollama:11434`, `http://mcp-server:8080`.
- **Порты наружу** — клиент из интернета ходит к сервисам напрямую,
  без reverse-proxy.

---

## Первичная настройка VPS (один раз)

### Docker и compose

```bash
sudo apt update && sudo apt -y upgrade
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
docker --version && docker compose version
```

### Swap 8 ГБ (на 16 ГБ RAM с Ollama — обязательно)

```bash
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h
```

### Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 11434/tcp        # Ollama
sudo ufw allow 8080:8082/tcp    # MCP (подставь свои порты)
sudo ufw allow 18789/tcp        # OpenClaw
sudo ufw allow 9119/tcp         # Hermes
sudo ufw enable
sudo ufw status numbered
```

### Общая docker-сеть (без неё `up` упадёт)

```bash
docker network create ai-net
docker network ls | grep ai-net
```

### Клон и конфиги

```bash
git clone https://github.com/rKhammatov/AI-DEVOPS.git ai-stack
cd ai-stack

```


---

## Ежедневная работа

### Запуск

```bash
# Ollama — запускаем первой, агенты к ней обращаются
docker compose -f ollama/docker-compose.yml up -d

# MCP — мой код, поднимется с пересборкой образа
docker compose -f mcp-server/docker-compose.yml up -d 

# OpenClaw — агент №1
docker compose -f openclaw/docker-compose.yml up -d

# Hermes — агент №2
docker compose -f hermes/docker-compose.yml up -d
```

### Остановка

```bash
# Один сервис: down = удалить контейнер (volumes остаются)
docker compose -f hermes/docker-compose.yml down

# Всё в обратном порядке (агенты первыми, Ollama последней)
for d in hermes openclaw mcp-server ollama; do
  docker compose -f $d/docker-compose.yml down
done

# ОПАСНО: down -v удаляет и тома (для Ollama = потеря всех моделей)
docker compose -f ollama/docker-compose.yml down -v
```

### Скачать модель в Ollama

```bash
docker exec -it ollama ollama pull llama3.1:8b-instruct-q4_K_M
docker exec ollama ollama list
```

---



---

## Обновление

```bash
# Один сервис с готовым образом (pull = скачать новый образ, up -d = перезапустить)
docker compose -f ollama/docker-compose.yml pull
docker compose -f ollama/docker-compose.yml up -d

# Один сервис с build 

docker compose -f mcp-server/docker-compose.yml pull
docker compose -f mcp-server/docker-compose.yml up -d
```

---

## Дебаг

### Логи

```bash
# Стрим логов одного сервиса (Ctrl+C прерывает)
docker compose -f openclaw/docker-compose.yml logs -f

# Последние 200 строк без стрима
docker compose -f openclaw/docker-compose.yml logs --tail=200

# Логи конкретного контейнера за последний час
docker logs --since 1h openclaw

# Все четыре контейнера разом, фильтр по слову "error"
docker logs -f ollama mcp-server openclaw hermes 2>&1 | grep -i error
```

### Статус и ресурсы

```bash
docker ps                                # что запущено
docker ps -a                             # включая остановленные
docker stats                             # live, как top
docker inspect openclaw --format '{{.State.Status}}'
docker inspect openclaw --format '{{.State.OOMKilled}}'
docker system df                         # место на диске
```

### Зайти внутрь

```bash
docker exec -it openclaw sh
docker exec -it ollama bash
docker exec -it mcp-server bash
docker exec -u 0 -it openclaw sh         # от root
```

### Сеть

```bash
# Кто в сети ai-net
docker network inspect ai-net --format \
  '{{range .Containers}}{{.Name}} ({{.IPv4Address}}) {{end}}'

# Резолвится ли имя
docker exec openclaw getent hosts ollama
docker exec hermes getent hosts mcp-server

# HTTP между контейнерами
docker exec openclaw wget -qO- http://ollama:11434/api/tags

# Порты на хосте
sudo ss -tulpn | grep -E '11434|18789|9119|8080'
```

---

## Перезапуск vs пересоздание

Все примеры — для MCP. Для других сервисов подставь нужный `-f путь`.

| Команда | Что делает | Когда нужна |
|---|---|---|
| `docker compose -f mcp-server/docker-compose.yml restart` | SIGTERM процессу в том же контейнере. Быстро. | Завис код, нужен мягкий рестарт. |
| `docker compose -f mcp-server/docker-compose.yml up -d` | Пересоздаёт контейнер, если что-то изменилось. | Применить правки в compose или .env. |
| `docker compose -f mcp-server/docker-compose.yml up -d --force-recreate` | Пересоздаёт всегда. | Когда `up -d` «не замечает» изменений. |
| `docker compose -f mcp-server/docker-compose.yml up -d --build` | Пересобирает образ перед запуском. | Изменил Dockerfile или src/. |
| `docker compose -f mcp-server/docker-compose.yml down && docker compose -f mcp-server/docker-compose.yml up -d` | Полный цикл. | Для уверенности. |

**Важно:** правки в `.env` НЕ подхватываются `restart`. Нужен `up -d`.

---

## Бэкап volumes

```bash
# Бэкап одного тома в tar.gz
docker run --rm \
  -v openclaw_openclaw_config:/data:ro \
  -v $(pwd):/backup \
  alpine tar czf /backup/openclaw-$(date +%F).tar.gz -C /data .

# Восстановление
docker run --rm \
  -v openclaw_openclaw_config:/data \
  -v $(pwd):/backup:ro \
  alpine sh -c 'cd /data && tar xzf /backup/openclaw-2026-05-15.tar.gz'

# Модели Ollama не бэкапь — перекачаются через `ollama pull`.
```

---

## Cleanup

```bash
docker container prune                  # остановленные контейнеры
docker image prune                      # dangling образы
docker system prune                     # всё неиспользуемое, кроме volumes
docker system prune -a                  # + неактивные образы с тэгами
docker system prune -a --volumes        # + volumes (ОПАСНО)
docker system df -v                     # сколько что занимает
```

---

## Типовые проблемы

```bash
# Контейнер в рестарт-петле
docker logs --tail=100 openclaw
docker inspect openclaw --format '{{.State.ExitCode}}: {{.State.Error}}'

# "network ai-net not found"
docker network create ai-net

# Port already allocated
sudo ss -tulpn | grep 11434
sudo lsof -i :11434

# OOM-killer прибил
docker inspect openclaw --format '{{.State.OOMKilled}}'
dmesg | tail -50 | grep -i 'killed process'

# Rate limit Docker Hub
docker login

# GHCR требует токен
echo $GHCR_PAT | docker login ghcr.io -u <user> --password-stdin
```

---

## Безопасность

Сервисы торчат в интернет — каждый защищается сам:

- **Ollama** по умолчанию **без auth**. Любой нашедший твой IP жжёт
  твой CPU. Минимум — sidecar с Bearer-токеном (Caddy/Nginx) или
  закрыть `11434` в UFW и ходить через ssh-туннель:
  `ssh -L 11434:localhost:11434 vps`.
- **OpenClaw** — обязательно `OPENCLAW_AUTH_TOKEN` в `.env`.
- **Hermes** — обязательно `HERMES_AUTH_TOKEN` в `.env`.
- **MCP** — API-key middleware на стороне кода.
- SSH: только ключи, `PasswordAuthentication no`, `fail2ban`.
- Регулярно: `sudo apt upgrade && docker compose pull && up -d`.

---

Каждая папка содержит собственный `docker-compose.yml`. Сеть `ai-net`
создаётся один раз вручную и общая для всех.
