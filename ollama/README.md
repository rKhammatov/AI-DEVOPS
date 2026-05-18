# Ollama

Локальный LLM-сервер, слушает HTTP на :11434.

## Команды

```bash
docker compose -f ollama/docker-compose.yml up -d        # запуск
docker compose -f ollama/docker-compose.yml down         # остановка
docker compose -f ollama/docker-compose.yml pull         # обновить образ
docker compose -f ollama/docker-compose.yml logs -f      # логи
```

## Модели

```bash
docker exec -it ollama ollama pull llama3.1:8b-instruct-q4_K_M
docker exec ollama ollama list
docker exec ollama ollama rm <model>
```

## Внутри ai-net

Другие контейнеры обращаются как `http://ollama:11434`.
