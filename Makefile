.PHONY: help setup start stop restart logs clean

help:
	@echo "AmakaFlow Workspace Commands"
	@echo ""
	@echo "  make setup    - Initial setup (create .env, build images)"
	@echo "  make start    - Start all services"
	@echo "  make stop     - Stop all services"
	@echo "  make restart  - Restart all services"
	@echo "  make logs     - View logs"
	@echo "  make clean    - Clean up containers and volumes"

setup:
	@test -f .env || (cp .env.example .env && echo "⚠️  Created .env - edit with your API keys!")
	@docker-compose build
	@echo "✅ Setup complete!"

start:
	@docker-compose up -d
	@echo "✅ Services started!"
	@echo ""
	@echo "URLs:"
	@echo "  UI:          http://localhost:3000"
	@echo "  Ingestor:    http://localhost:8004/docs"
	@echo "  Mapper:      http://localhost:8001/docs"
	@echo "  Strava:      http://localhost:8000/docs"
	@echo "  Calendar:    http://localhost:8003/docs"

stop:
	@docker-compose down

restart:
	@docker-compose restart

logs:
	@docker-compose logs -f

clean:
	@docker-compose down -v

.DEFAULT_GOAL := help
