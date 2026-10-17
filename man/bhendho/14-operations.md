# Эксплуатация ядра

**Зачем это.** Что оператор делает с ядром на сервере: команды, настройки, проверки, выпуск версий.

## Команды `core`

Одна программа, подкоманды — [cmd/core/main.go](https://github.com/vlad78831457/bhendho/blob/v0.3.0/cmd/core/main.go).
В сборке их зовут так: `docker compose -f deploy/compose.yaml exec core /core <команда>`.

| Команда | Что |
|---|---|
| `serve` | запуск ядра: миграции, фоновые работы, HTTP |
| `migrate` | только миграции |
| `user-role --user <email или id> [--role user\|tester\|admin]` | выдать роль; без `--role` — показать |
| `check-module <каталог>` | проверить паспорт и бланки правилами ядра, без базы |
| `promo-codes --amount 500 [--count 10] [--email …]` | подарочные промокоды; печатаются один раз |
| `promo-issuer --name shop` | токен службы оплаты; один раз |
| `issue-token --service tale --name p1` | токен прораба старым способом. Обычно ключ выдаёт админ в панели |
| `healthz` | отвечает ли HTTP — для проверки здоровья контейнера |

## Настройки

Все числа — переменные `CORE_…` ([config.go](https://github.com/vlad78831457/bhendho/blob/v0.3.0/internal/core/config/config.go)).
Действующие значения без секретов — панель → «Настройки».

| Группа | Переменные |
|---|---|
| адрес, база | `CORE_HTTP_ADDR`, `DATABASE_URL`, `CORE_DB_MAX_CONNS`, `CORE_PUBLIC_URL` |
| вход | `JWT_SECRET`, `CORE_ACCESS_TTL`, `CORE_REFRESH_TTL`, `CORE_AUTH_HASH_CONCURRENCY`, `CORE_OAUTH_*` |
| задачи | `CORE_ACCEPT_TIMEOUT`, `CORE_DEFAULT_ETA`, `CORE_LOCK_MULTIPLIER`, `CORE_LOCK_CEILING`, `CORE_MAX_ATTEMPTS`, `CORE_SWEEP_INTERVAL`, `CORE_TASK_RETENTION`, `CORE_TRACE_TTL` |
| деньги | `CORE_DEFAULT_CURRENCY`, `CORE_OVERDRAFT_FACTOR`, `CORE_DEMO_DEPOSIT`, `CORE_DEMO_DEPOSIT_MAX` |
| оплата | `CORE_PROMO_ISSUERS`, `CORE_PROMO_MAX_AMOUNT`, `CORE_PROMO_MAX_FAILURES`, `CORE_PROMO_FAILURE_WINDOW`, `CORE_TOPUP_MARK_TTL` |
| файлы | `CORE_STORAGE_DIR`, `CORE_FILE_MAX_BYTES`, `CORE_FILE_MAX_PER_USER`, `CORE_IMAGE_MAX_SIDE`, `CORE_FILE_LINK_TTL` |
| события | `CORE_OUTBOX_BATCH`, `CORE_OUTBOX_INTERVAL`, `CORE_WS_ORIGINS`, `CORE_WS_PING_INTERVAL`, `CORE_CATALOG_TTL` |
| старый способ подключения | `CORE_MODULES_DIR`, `CORE_PRORAB_TOKENS` |
| прочее | `CORE_SHOWCASE_LANGUAGE`, `CORE_PPROF_ADDR` (профилировщик, только для отладки) |

## Здоровье

| Проверка | Что значит |
|---|---|
| `GET /healthz`, `core healthz` | HTTP отвечает; база и миграции не нужны. Так проверяет compose |
| `GET /readyz` | база доступна, можно работать |

## Версии и выпуск

- `bhendho` — **строгий** открытый репозиторий: каждое изменение — отдельный PR с отчётом. Директор вливает.
- Выпуск — тег `vX.Y.Z` на `main` и выпуск на GitHub. Теги ставятся только по команде директора.
- Сборки берут ядро **по тегу**:
  - `orb-tale-eco/repos.yaml`: `version: v0.3.0`;
  - SDK Python — `BHENDHO_SDK_REF` в Dockerfile воркера;
  - SDK фронта — `BHENDHO_REF` в Dockerfile экрана.
- Обновить ядро в сборке — поменять тег в трёх местах и прогнать `make e2e`
  ([tale/14-recipes](../tale/14-recipes.md)).

## Проверки ядра

| Команда в `bhendho` | Что |
|---|---|
| `make test` | Go-тесты, в том числе сквозные на настоящем Postgres; заготовка подразделения проходит `check-module`; тесты SDK |
| `scripts/e2e.sh` | сквозная проверка ядра с прорабом |
