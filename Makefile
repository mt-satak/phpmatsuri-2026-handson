# よく使う docker compose コマンドの短縮
# 例: make artisan c="migrate"  /  make npm c="install"

.PHONY: build up down ps logs shell dev artisan composer npm mysql versions ai-check

build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f

shell:
	docker compose exec app bash

dev:
	docker compose exec app composer run dev

artisan:
	docker compose exec app php artisan $(c)

composer:
	docker compose exec app composer $(c)

npm:
	docker compose exec app npm $(c)

mysql:
	docker compose exec mysql mysql -ularavel -ppassword laravel

versions:
	@docker compose exec app php -v | head -1
	@docker compose exec app composer -V
	@docker compose exec app sh -c 'echo "node $$(node -v) / npm $$(npm -v)"'
	@docker compose exec app laravel --version
	@docker compose exec mysql mysql -uroot -ppassword -N -e 'SELECT CONCAT("MySQL ", VERSION());' 2>/dev/null

# Laravel AI SDK の疎通確認（src/.env に ANTHROPIC_API_KEY を設定してから実行）
ai-check:
	docker compose exec app php artisan tinker --execute='echo Laravel\Ai\agent("あなたは簡潔に答えるアシスタントです。")->prompt("phpMatsuri へようこそ、と一言で返して"), PHP_EOL;'
