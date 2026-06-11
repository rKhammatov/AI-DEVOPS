# nginx reverse-proxy — пошаговая инструкция

## Как это устроено

```
Интернет ──► Внешний фронт ──► nginx на этом сервере ──► сервисы в Docker
            (настоящий серт      (самоподписанный          openclaw  :18789
             *.sblabs.ru)         сертификат)              ouroboros :8765
                                                           mvp       :5042 + :5043 (ws)
```

- nginx ставится **прямо на хост** (через dnf), сервисы остаются в Docker.
- nginx понимает, к какому сервису пришёл запрос, **по поддомену** (заголовок Host).
- Сертификат на этом сервере — самоподписанный: он шифрует только участок
  «фронт → сервер». Настоящий сертификат живёт на фронте. **Certbot не нужен.**

## Файлы в этой папке

| Файл | Куда копировать на сервере | Что делает |
|---|---|---|
| `conf.d/00-common.conf` | `/etc/nginx/conf.d/` | общие настройки (websocket, IP клиента) |
| `conf.d/00-default.conf` | `/etc/nginx/conf.d/` | заглушка: обрывает запросы по голому IP |
| `conf.d/openclaw.conf` | `/etc/nginx/conf.d/` | прокси на openclaw |
| `conf.d/ouroboros.conf` | `/etc/nginx/conf.d/` | прокси на ouroboros |
| `conf.d/mvp.conf` | `/etc/nginx/conf.d/` | прокси на mvp (HTTP + ws) |

## Перед началом: подставь свои значения

Открой конфиги и пройдись по меткам **`ЗАМЕНИ`** — их легко найти поиском.
В шапке каждого файла перечислено, что именно в нём менять:

1. **Поддомены** (`server_name`) — в каждом сервисном конфиге, в двух местах.
2. **IP внешнего фронта** (`set_real_ip_from`) — в `00-common.conf`.
3. **Порты сервисов** (`proxy_pass`) — если отличаются от 18789 / 8765 / 5042+5043.
4. **Лимит загрузки файлов** (`client_max_body_size`) — сейчас 50 МБ.

---

# Установка: 8 шагов по порядку

## Шаг 1 из 8 — проверь сервер и DNS

**Что делаем:** убеждаемся, что сервер тот, что мы думаем, и DNS настроен.

```bash
cat /etc/os-release        # какой дистрибутив
getenforce                 # режим SELinux
dig +short openclaw.sblabs.ru
dig +short ouroboros.sblabs.ru
dig +short mvp.sblabs.ru
```

**Результат:** дистрибутив — RHEL-семейство; `getenforce` скорее всего покажет
`Enforcing` (тогда шаг 4 обязателен); каждый `dig` вернул **IP внешнего фронта**
(не этого сервера!). Если dig вернул пусто — сначала заведи DNS-записи.

## Шаг 2 из 8 — установи nginx

```bash
sudo dnf install -y nginx
sudo systemctl enable --now nginx
nginx -v
```

**Результат:** `nginx -v` напечатал версию (например `nginx/1.20.1`).

## Шаг 3 из 8 — создай сертификат

**Что делаем:** генерируем самоподписанный сертификат на 5 лет.
Одна команда — она создаст и ключ, и сертификат.

```bash
sudo mkdir -p /etc/nginx/ssl

sudo openssl req -x509 -nodes -newkey rsa:4096 \
  -days 1825 \
  -keyout /etc/nginx/ssl/sblabs-selfsigned.key \
  -out    /etc/nginx/ssl/sblabs-selfsigned.crt \
  -subj   "/CN=*.sblabs.ru" \
  -addext "subjectAltName=DNS:*.sblabs.ru,DNS:sblabs.ru"

# Права: ключ читает только root
sudo chown root:root /etc/nginx/ssl/sblabs-selfsigned.*
sudo chmod 600 /etc/nginx/ssl/sblabs-selfsigned.key
sudo chmod 644 /etc/nginx/ssl/sblabs-selfsigned.crt

# Поправить SELinux-метки на новых файлах
sudo restorecon -Rv /etc/nginx/ssl
```

**Результат:** в `/etc/nginx/ssl/` лежат два файла — `.key` и `.crt`.
Проверить: `ls -l /etc/nginx/ssl/`.

## Шаг 4 из 8 — разреши nginx ходить к сервисам (SELinux)

**Что делаем:** по умолчанию SELinux **запрещает** nginx подключаться к другим
портам. Без этой команды все запросы будут падать с ошибкой 502.

```bash
sudo setsebool -P httpd_can_network_connect 1
```

**Результат:** команда отработала молча — это нормально. Флаг сохраняется
навсегда (ключ `-P`), повторять после перезагрузки не нужно.

> Если позже поменяешь `listen` на нестандартный порт (не 80/443) — SELinux
> не даст nginx его слушать. Лечится так:
> `sudo semanage port -a -t http_port_t -p tcp <порт>`

## Шаг 5 из 8 — скопируй конфиги на сервер

**Что делаем:** переносим все 5 файлов из `conf.d/` этой папки
в `/etc/nginx/conf.d/` на сервере.

```bash
# На своей машине, из папки nginx-devops/:
scp conf.d/*.conf user@<IP-сервера>:/tmp/

# На сервере:
sudo mv /tmp/00-common.conf /tmp/00-default.conf /tmp/openclaw.conf /tmp/ouroboros.conf /tmp/mvp.conf /etc/nginx/conf.d/
sudo chown root:root /etc/nginx/conf.d/*.conf
sudo restorecon -Rv /etc/nginx/conf.d
```

**Результат:** `ls /etc/nginx/conf.d/` показывает все 5 файлов.

## Шаг 6 из 8 — отключи дефолтный сайт nginx

**Что делаем:** в стандартном `/etc/nginx/nginx.conf` уже есть свой
`server`-блок — он конфликтует с нашей заглушкой `00-default.conf`.

Открой файл:

```bash
sudo nano /etc/nginx/nginx.conf
```

Найди блок, начинающийся со строки `server {` (внутри него есть
`listen 80 default_server;`), и закомментируй его **целиком** — от `server {`
до парной закрывающей `}` — поставив `#` в начале каждой строки.

**Результат:** в `nginx.conf` не осталось ни одного незакомментированного
`server`-блока. Если пропустить этот шаг, следующий шаг упадёт с ошибкой
`duplicate default server`.

## Шаг 7 из 8 — проверь и примени

```bash
sudo nginx -t                   # проверка конфигурации
sudo systemctl reload nginx     # применение (без обрыва соединений)
```

**Результат:** `nginx -t` напечатал две строки — `syntax is ok` и
`test is successful`. Если есть ошибка — в ней написан файл и номер строки.

## Шаг 8 из 8 — проверь, что всё работает

**Проверка 1 — редирект с http на https** (выполняется на сервере):

```bash
curl -s -o /dev/null -w "%{http_code} -> %{redirect_url}\n" -H "Host: openclaw.sblabs.ru" http://127.0.0.1/
```

Ожидаем: `301 -> https://openclaw.sblabs.ru/`. Повтори с Host остальных сервисов.

**Проверка 2 — https до каждого сервиса** (`-k` нужен, т.к. серт самоподписанный):

```bash
curl -sk -o /dev/null -w "%{http_code}\n" -H "Host: openclaw.sblabs.ru"  https://127.0.0.1/
curl -sk -o /dev/null -w "%{http_code}\n" -H "Host: ouroboros.sblabs.ru" https://127.0.0.1/
curl -sk -o /dev/null -w "%{http_code}\n" -H "Host: mvp.sblabs.ru"       https://127.0.0.1/
```

Ожидаем: код самого сервиса — `200`, `302` или `401`. Главное — **не `502`**
(если 502 — см. раздел «Если 502» внизу).

**Проверка 3 — websocket mvp:**

```bash
curl -sk -i -N --max-time 5 \
  -H "Host: mvp.sblabs.ru" \
  -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
  https://127.0.0.1/ws | head -1
```

Ожидаем: `HTTP/1.1 101 Switching Protocols`.

**Проверка 4 — через фронт** (с любой внешней машины, `-k` уже не нужен):

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://openclaw.sblabs.ru/
curl -s -o /dev/null -w "%{http_code}\n" https://ouroboros.sblabs.ru/
curl -s -o /dev/null -w "%{http_code}\n" https://mvp.sblabs.ru/
```

Ожидаем: те же коды, что в проверке 2. Если здесь не работает, а проверка 2
работала — проблема на фронте, см. «Чек-лист фронта» ниже.

---

# Настройка openclaw за прокси

nginx настроен, но сам openclaw тоже нужно настроить (по docs.openclaw.ai),
иначе Control UI не пустит через прокси. Три настройки:

| Настройка | Значение | Зачем |
|---|---|---|
| `gateway.trustedProxies` | `["127.0.0.1"]` | Gateway начинает доверять заголовкам от nginx |
| `gateway.controlUi.allowedOrigins` | публичные URL | разрешает открывать Control UI с этих адресов |
| `gateway.auth.mode` | `token` | вход по токену (режим `trusted-proxy` НЕ использовать) |

Готовые команды:

```bash
openclaw config set gateway.trustedProxies '["127.0.0.1"]'
openclaw config set gateway.controlUi.allowedOrigins '["https://openclaw.sblabs.ru","https://openclaw-test.sblabs.ru"]'
openclaw config set gateway.auth.mode token
openclaw config set gateway.auth.token "$(openssl rand -hex 32)"
```

Или тот же фрагмент для `~/.openclaw/openclaw.json` вручную:

```json
{
  "gateway": {
    "trustedProxies": ["127.0.0.1"],
    "controlUi": {
      "allowedOrigins": [
        "https://openclaw.sblabs.ru",
        "https://openclaw-test.sblabs.ru"
      ]
    },
    "auth": {
      "mode": "token",
      "token": "ЗАМЕНИ-длинный-случайный-токен"
    }
  }
}
```

> Поддомены в `allowedOrigins` должны совпадать с `server_name` в `openclaw.conf`.

После настройки перезапусти openclaw (`docker compose ... up -d`).

---

# Справка

## Чек-лист фронта

Если через фронт не работает, а напрямую с сервера работает — проверь на фронте:

- [ ] **Host передаётся без изменений.** nginx выбирает сервис по Host;
      если фронт его переписал — все запросы упадут в заглушку (обрыв соединения).
- [ ] **WebSocket проксируется** (HTTP/1.1, заголовки Upgrade/Connection
      пропускаются, долгие соединения не режутся таймаутом фронта).
- [ ] **X-Forwarded-For отправляется** с реальным IP клиента.
- [ ] **Самоподписанный сертификат принимается** — проверка серта апстрима
      отключена, либо фронту добавлен наш `.crt` как доверенный.
- [ ] **Трафик идёт на порт 443** этого сервера.

## Если 502 — почти наверняка SELinux

Симптом: в браузере 502, а в `/var/log/nginx/error.log` строка
`connect() ... failed (13: Permission denied) while connecting to upstream`.

```bash
getenforce                       # Enforcing?
sudo ausearch -m avc -ts recent  # свежие блокировки (ищи comm="nginx")
sudo setsebool -P httpd_can_network_connect 1   # лечение (шаг 4)
```

Если ругань идёт на файлы сертификата — слетели SELinux-метки:
`sudo restorecon -Rv /etc/nginx/ssl`.

## Перевыпуск сертификата (когда истечёт)

Посмотреть срок: `openssl x509 -in /etc/nginx/ssl/sblabs-selfsigned.crt -noout -dates`.

Перевыпуск = повторить команду из шага 3 (она перезапишет старые файлы), затем:

```bash
sudo restorecon -Rv /etc/nginx/ssl
sudo nginx -t && sudo systemctl reload nginx
```

## Перенос на боевой сервер

Конфиги те же, меняются только значения. По порядку:

1. В `openclaw.conf`, `ouroboros.conf`, `mvp.conf` — боевые поддомены (`server_name`).
2. В `proxy_pass` — боевые порты, если отличаются.
3. В `00-common.conf` — IP боевого фронта (`set_real_ip_from`).
4. Сертификат **не переносить** — сгенерировать на бою заново (шаг 3).
5. Дальше шаги 4–8 без изменений.

## Типовые проблемы

| Симптом | Причина и лечение |
|---|---|
| `nginx -t`: duplicate default server | не выполнен шаг 6 (дефолтный блок в nginx.conf) |
| 502 | SELinux — см. раздел выше; или сервис в Docker не запущен |
| Валидный поддомен получает обрыв соединения | фронт переписывает Host — чек-лист фронта |
| ws рвётся через ~минуту | запрос идёт мимо ws-location (у mvp проверь путь `/ws`) или фронт режет долгие соединения |
| Ouroboros UI открылся, но «не живой» | не проходит websocket — проверка 3 из шага 8, но с Host ouroboros |
| 413 Request Entity Too Large | увеличь `client_max_body_size` в конфиге сервиса + reload |
