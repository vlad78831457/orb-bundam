# Путь одной сказки через код

**Зачем это.** Одна сказка проходит через всю систему: от кнопки «Соткать сказку» до вызова внешней модели и
обратно на экран. Здесь путь расписан по шагам. На каждом шаге — **файл и функция**, чтобы пройти его в коде
самому.

## Схема целиком

```mermaid
sequenceDiagram
  autonumber
  actor U as Человек
  participant S as screen/backend.ts
  participant C as ядро: tasks.go
  participant G as ядро: gateway.go
  participant W as SDK: Worker
  participant H as main.handle
  participant P as Pipeline
  participant St as Story
  participant R as Registry
  participant X as внешний API
  participant M as LocalMedia
  U->>S: «Соткать сказку»
  S->>C: createFact + publish — герои
  S->>C: POST /api/v1/tasks generate_start
  C->>C: CreateTask: поля, ссылки, резерв 150
  W->>G: claim
  G-->>W: задача + снимок (герои раскрыты)
  W->>W: estimate → accept(ETA)
  W->>H: handle(ctx)
  H->>P: pipeline.start(values, progress, meter)
  P->>R: for_language("ru")
  R-->>P: Providers(text, image, audio)
  P->>St: style_bible, start(prefs)
  St->>X: text.generate — YandexGPT
  X-->>St: JSON сюжета, токены
  P->>St: cast_voices — кто каким голосом
  par страницы параллельно
    P->>X: image.generate — YandexART
    P->>X: audio.synthesize — SpeechKit
  end
  P->>M: save png, mp3 → /media/…
  P-->>H: состояние сказки
  H->>H: ctx.charge(tokens, images, tts_seconds)
  W->>G: commit success: result + worker_charge
  G->>C: settle: факт v1, charge, release
  C-->>S: события task.progress, task.status, wallet.changed
  S-->>U: книга со страницами
```

## По шагам

### 1. Экран: герои и задача

| Шаг | Где | Что |
|---|---|---|
| герои | [screen/src/tale/backend.ts](https://github.com/vlad78831457/orb-tale-servo/blob/main/screen/src/tale/backend.ts) `createHeroes` | каждый герой — `createFact(taleweaver.character.v1)` и публикация: задача примет только опубликованных |
| хватит ли денег | там же, `ensureFunds` | цена бланка против `available`; не хватает — предложить «Пополнить» |
| состояние экрана → бланк | [screen/src/tale/mapping.ts](https://github.com/vlad78831457/orb-tale-servo/blob/main/screen/src/tale/mapping.ts) | настройки «стола сказочника» → `values` бланка |
| задача | `backend.ts` `startTale` → `api.createTask(START_FORM, values, uuid())` | ключ идемпотентности — новый `uuid` |
| прогресс | `backend.ts` — подписка на события | `task.progress` → полоса прогресса, `task.status` → готово |

### 2. Ядро: принять задачу

[engine/tasks.go](https://github.com/vlad78831457/bhendho/blob/v0.3.1/internal/core/engine/tasks.go) `CreateTask`:
1. поля по `fields_rules`;
2. герои опубликованы;
3. резерв 150 GC;
4. `pending`.

Подробно — [bhendho/06-tasks](../bhendho/06-tasks.md).

### 3. Прораб: взять задачу

| Шаг | Где |
|---|---|
| опрос очереди | SDK [worker.py](https://github.com/vlad78831457/bhendho/blob/v0.3.1/pkg/sdk/python/src/offgrid_worker/worker.py) `Worker.run_once` → `GatewayClient.claim` |
| выбор прораба и снимок | ядро [gateway.go](https://github.com/vlad78831457/bhendho/blob/v0.3.1/internal/core/engine/gateway.go) `Claim`, `materialize` |
| оценка | [main.py](https://github.com/vlad78831457/orb-tale-servo/blob/main/worker/src/taleweaver_worker/main.py) `estimate` → `accept(eta)` |
| обработчик | `main.py` `make_handler` → `handle(ctx)` → фото героев `ctx.file` → `Pipeline.start` |

### 4. Конвейер: сюжет

[pipeline.py](https://github.com/vlad78831457/orb-tale-servo/blob/main/worker/src/taleweaver_worker/pipeline.py) `Pipeline.start`:
1. `preferences_from(values)` — пожелания из бланка;
2. `registry.for_language(language)` — какие провайдеры для этого языка;
3. `progress(5, "plot")`;
4. `story.style_bible(prefs)` — если нужны картинки;
5. `story.full(prefs)` или `story.start(prefs)` — сюжет целиком или до развилки.

[story.py](https://github.com/vlad78831457/orb-tale-servo/blob/main/worker/src/taleweaver_worker/story.py)
`Story._chat`:
- зовёт `text.generate(system, user, max_tokens)` — **первый выход во внешний API**;
- прибавляет `meter.tokens`;
- `extract_json` разбирает ответ. Не JSON — `StoryError` → повтор задачи.

### 5. Конвейер: страницы и медиа

`Pipeline._segment`:
1. `cast_voices` — модель назначает персонажам голоса из реестра провайдера озвучки, `progress(20, "voice_casting")`;
2. страницы `_page(...)`: `text` с разметкой и `plain_text`, `progress(30, "text_ready")`;
3. `_media_for` — картинки и озвучка.

`Pipeline._media_for`:
- **опорная картинка.** Если в сказке её ещё нет, первая страница рисуется отдельно. Её картинка — образец
  стиля для остальных и для будущих продолжений. Фото героев идут образцами в каждую картинку;
- **картинка страницы:** `story.image_prompt(...)` (модель текста пишет промпт) → `image.generate(prompt, refs)`
  — **внешний API картинок** → `media.save` → `image_url`;
- **озвучка страницы:** `PageAudio.build(...)` → `audio.synthesize` по репликам — **внешний API речи** →
  сборка mp3 → `audio_url`;
- каждая страница — в `_guard`: место в очереди (семафор), затем таймаут и перехват. Одна упавшая страница
  остаётся без картинки или звука, но не валит сказку;
- прогресс `30 + 65 × готово/всего`, фаза `media k/n`.

### 6. Отчёт и деньги

| Шаг | Где |
|---|---|
| счёт | `main.handle`: `ctx.charge("tokens", meter.tokens)`, `images`, `tts_seconds` |
| результат | `Outcome(result=state, report={"segment": …})` |
| сдача | SDK `commit_success(result, charge, report)` |
| засчитать | ядро `Commit` → `settle`: проверить сказку по бланку `tale`, факт v1 `published`, списание и возврат |
| показать | `outbox` → `realtime` → `backend.ts` → `loadTale` |

## Продолжение

```mermaid
sequenceDiagram
  participant S as backend.ts continueTale
  participant C as ядро
  participant P as Pipeline.continue_
  S->>C: createTask(generate_continue, {tale, choice_index}, group = id сказки)
  C->>C: ждёт, пока в группе нет незавершённой раньше
  C-->>P: снимок: tale = опубликованная версия целиком
  P->>P: статус awaiting_choice? ровно один выбор? индекс в границах?
  alt нет
    P-->>C: SegmentError → DATA_REJECTED, резерв назад
  else да
    P->>P: story.continuation(prefs, текст до этого, выбор)
    P->>P: _segment: новые страницы и медиа, старые не трогаем
    P-->>C: success → версия n+1 той же сказки, прежняя → archived
  end
```

## Как пройти путь руками

- `make e2e` в `orb-tale-eco`: от регистрации и оплаты до сказки и «поделиться».
- [test_tale_e2e.py](https://github.com/vlad78831457/orb-tale-servo/blob/main/worker/tests/e2e/test_tale_e2e.py):
  старт → два продолжения → отказ на завершённой сказке → проверка денег.
- Логи прораба: `docker compose -f deploy/compose.yaml logs -f worker`.
- Трасса задачи в базе: `task_trace` ([bhendho/06-tasks](../bhendho/06-tasks.md#как-проверить)).
