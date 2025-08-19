.PHONY: help build up down restart logs shell test lint format clean migrate collectstatic createsuperuser

# Default target
help: ## Mostrar este mensaje de ayuda
	@echo "Comandos disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Docker commands
rebuild: ## Reconstruir las imágenes de Docker
	docker compose up -d --build

build: ## Construir las imágenes de Docker
	docker compose build

up: ## Levantar todos los servicios
	docker compose up -d

down: ## Parar todos los servicios
	docker compose down

restart: ## Reiniciar todos los servicios
	docker compose restart

logs: ## Ver logs de todos los servicios
	docker compose logs -f

logs-web: ## Ver logs del servicio web
	docker compose logs -f web

# Development commands
shell: ## Abrir shell del servidor web
	docker compose exec web bash

dbshell: ## Abrir shell de PostgreSQL
	docker compose exec db psql -U maybe_user -d maybe_production

import-market-data: ## Ejecutar el job ImportMarketDataJob para importar datos de mercado
	docker compose exec web bundle exec rails runner "ImportMarketDataJob.perform_now(mode: 'snapshot', clear_cache: false)"



