.PHONY: preflight up-local up-local-build up-local-detached up-local-quick build-local down-local ps-local logs-local stats-local health-local
.PHONY: restart-flask restart-stt restart-laravel restart-frontend restart-postgres

COMPOSE_FILE := one-local.docker-compose.yml
COMPOSE := docker compose -f $(COMPOSE_FILE)

preflight:
	chmod +x ./scripts/local-compose-preflight.sh
	./scripts/local-compose-preflight.sh

up-local: preflight
	$(COMPOSE) up -d

up-local-build:
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 $(COMPOSE) up --build

up-local-detached: preflight
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 $(COMPOSE) up --build -d

up-local-quick: preflight
	$(COMPOSE) up -d

build-local:
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 $(COMPOSE) build --parallel

down-local:
	$(COMPOSE) down

ps-local:
	$(COMPOSE) ps

logs-local:
	$(COMPOSE) logs -f --tail=100

stats-local:
	$(COMPOSE) stats

health-local:
	curl -f http://127.0.0.1:5000/health
	curl -f http://127.0.0.1:5001/
	curl -f http://127.0.0.1:3000/
	curl -f http://127.0.0.1:7000/health/live
	curl -f http://127.0.0.1:8000/up

restart-flask:
	$(COMPOSE) restart python-flask-api
	$(COMPOSE) logs -f --tail=100 python-flask-api

restart-stt:
	$(COMPOSE) restart speech-to-text-streaming

restart-laravel:
	$(COMPOSE) restart laravel-backend

restart-frontend:
	$(COMPOSE) restart frontend-next

restart-postgres:
	$(COMPOSE) restart postgres
