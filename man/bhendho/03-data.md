# Данные

**Зачем это.** Всё состояние системы — в одной базе Postgres. Здесь таблицы ядра по группам и связи между ними.
Схема строится 21 миграцией — [db/migrations/](https://github.com/vlad78831457/bhendho/tree/v0.3.1/internal/core/db/migrations),
от `0001_core.sql` до `0021_prorab_info.sql`. Ядро запускает их само при старте.

Подразделения своей базы в ядре не имеют. Их данные — факты пользователей и память подразделения
(`service_facts`).

## Люди и деньги

```mermaid
erDiagram
  users ||--o{ wallets : "владеет (owner_kind=user)"
  services ||--|| wallets : "кошелёк дохода"
  wallets ||--o{ transactions : "журнал"
  users ||--o{ deposits : "пополнения"
  deposits ||--o{ payment_events : "события оплаты"
  users ||--o{ user_identities : "внешние входы"
  users ||--o{ refresh_tokens : "сессии"
  users {
    uuid id
    text email
    text role "user | tester | admin"
    text source "utm"
    int priority
  }
  wallets {
    uuid id
    text owner_kind "user | service"
    numeric balance "может быть ниже 0 (минус)"
    numeric reserved
  }
  transactions {
    bigint id
    text type "deposit reserve charge overcharge release income refund adjust"
    numeric amount
    uuid task_id
    jsonb units "счёт прораба"
    jsonb rates "курсы задачи"
  }
```

## Бланки, факты, задачи

```mermaid
erDiagram
  services ||--o{ forms : "бланки подразделения"
  forms ||--o{ system_tasks : "задача по бланку (form_id, version)"
  users ||--o{ facts : "владеет"
  facts ||--o{ fact_versions : "версии"
  users ||--o{ system_tasks : "создал"
  system_tasks ||--o{ task_trace : "трасса"
  services ||--o{ service_facts : "память подразделения"
  users ||--o{ files : "файлы"
  facts ||--o{ shares : "ссылки"
  facts ||--o{ showcase : "на витрине"
  forms {
    text form_id
    int version
    text kind "fact | task"
    jsonb meta_ui "fields_rules и подписи"
    numeric price
    text status "draft published withdrawn"
    jsonb result_spec
    text audience
    jsonb user_marks
  }
  facts {
    uuid id
    text kind "form_id факта"
    text origin "user | task:id"
  }
  fact_versions {
    int version
    text status "draft published archived deleted"
    jsonb values
  }
  system_tasks {
    uuid id
    text status "pending processing completed failed cancelled"
    jsonb values
    jsonb materialized "снимок для прораба"
    numeric reserved
    jsonb rates_fixed
    uuid group_id
    uuid locked_by "прораб"
    timestamptz locked_until
    int attempts
    text verdict
    jsonb report
    jsonb result
  }
```

## Подразделения, прорабы, оплата

```mermaid
erDiagram
  department_keys ||--o{ service_accounts : "по ключу подключается прораб"
  services ||--o{ service_accounts : "прорабы"
  services ||--o{ prorab_priorities : "кто какой бланк берёт"
  promo_issuers ||--o{ promo_codes : "выпустил"
  users ||--o{ topup_marks : "метки «Пополнить»"
  topup_marks |o--o| promo_codes : "зачислено кодом"
  services {
    text code "target_service"
    text module_id
    jsonb accounting "единицы учёта"
    jsonb views "разметка"
    bool enabled
  }
  service_accounts {
    text name "имя прораба"
    text token_hash
    text title
    text description
    timestamptz last_seen_at
    timestamptz revoked_at
  }
  department_keys {
    text code "подразделение"
    text name "прораб"
    text token_hash "dk_…"
  }
  prorab_priorities {
    text prorab
    text form_id
    int priority "0 — не берёт"
  }
  promo_codes {
    text code_hash
    numeric amount
    text external_id "номер оплаты"
    text status
  }
```

## Служебные таблицы

| Таблица | Что | Миграция |
|---|---|---|
| `outbox_queue` | события пользователю, ждущие доставки (`pending` → `sent`, номер `seq`) | 0001 |
| `user_seq` | последний номер события пользователя | 0001 |
| `task_trace` | трасса задачи: этапы, кто, код | 0001 |
| `currencies` | валюты, по умолчанию `GC` | 0001 |
| `tariff_changes` и вид `tariffs` | журнал правок тарифов и последнее действующее значение | 0014 |
| `oauth_states`, `oauth_logins` | одноразовые шаги входа через внешний аккаунт | 0005 |
| `promo_failures` | неудачные попытки ввода кода, против подбора | 0004 |

## Что когда появилось

| Миграция | Что |
|---|---|
| 0001 | ядро: пользователи, кошельки, проводки, бланки, факты, задачи, подразделения, события, файлы |
| 0002 | факт-результат задачи (`result_spec`) |
| 0004 | промокоды и эмитенты |
| 0005–0006 | внешние входы, кабинет |
| 0007 | размеры картинок |
| 0008 | роли |
| 0009 | метки «Пополнить» |
| 0010 | минус: баланс может быть ниже нуля, проводка `overcharge` |
| 0011–0013 | память подразделения, «кому», пометки пользователя в снимке задачи |
| 0014 | тарифы |
| 0015–0016 | ключи подразделений, выключатель, разметка |
| 0017–0019 | ссылки «поделиться», витрина, метка источника |
| 0020–0021 | приоритеты и сведения о прорабах |

## Как проверить

- Таблицы на живой системе:
  `docker compose -f deploy/compose.yaml exec postgres psql -U offgrid -d offgrid -c '\dt'`.
- Выгрузка всей базы за период из панели — ZIP с файлом на таблицу ([10-front](10-front.md)).
