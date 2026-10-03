# orb-bundam. Проверки — в Docker; sync и status — git на VM (ключи в контейнер не попадают).
.PHONY: help sync status test

help: ## список команд
	@grep -E '^[a-z-]+:.*## ' Makefile | sed 's/:.*## /\t/'

sync: ## клонировать или обновить repos/ по repos.yaml
	@sh tools/sync.sh

status: ## ветка, отставание и незакоммиченное в каждом подрепозитории
	@sh tools/status.sh

test: ## проверка репозитория (Docker)
	docker compose build -q test
	docker compose run --rm test
