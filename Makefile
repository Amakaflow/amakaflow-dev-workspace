.PHONY: help setup start stop restart logs clean build status watch \
        ui chat mapper calendar ingestor \
        logs-ui logs-chat logs-mapper logs-calendar logs-ingestor

# =============================================================================
# MAIN COMMANDS
# =============================================================================

help:
	@echo "AmakaFlow Dev Workspace"
	@echo ""
	@echo "Setup:"
	@echo "  make setup      - Initial setup (create .env, build images)"
	@echo "  make build      - Rebuild all images"
	@echo ""
	@echo "Running:"
	@echo "  make start      - Start all services"
	@echo "  make watch      - Start all services + auto-rebuild on requirements.txt changes"
	@echo "  make stop       - Stop all services"
	@echo "  make restart    - Restart all services"
	@echo "  make status     - Show service status"
	@echo ""
	@echo "Logs:"
	@echo "  make logs       - View all logs"
	@echo "  make logs-ui    - View UI logs"
	@echo "  make logs-chat  - View chat-api logs"
	@echo "  make logs-mapper    - View mapper-api logs"
	@echo "  make logs-calendar  - View calendar-api logs"
	@echo "  make logs-ingestor  - View workout-ingestor logs"
	@echo ""
	@echo "Individual Services:"
	@echo "  make ui         - Start only UI"
	@echo "  make chat       - Start only chat-api"
	@echo "  make mapper     - Start only mapper-api"
	@echo "  make calendar   - Start only calendar-api"
	@echo "  make ingestor   - Start only workout-ingestor"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean      - Stop and remove containers/volumes"

setup:
	@test -f .env || (cp .env.example .env && echo "Created .env - edit with your API keys!")
	@docker compose build
	@echo ""
	@echo "Setup complete!"
	@echo "Edit .env with your API keys, then run: make start"

build:
	@docker compose build --no-cache

watch:
	@docker compose up -d
	@docker compose watch

start:
	@docker compose up -d
	@echo ""
	@echo "Services starting..."
	@echo ""
	@echo "URLs:"
	@echo "  UI:        http://localhost:3000"
	@echo "  Chat:      http://localhost:8005/docs"
	@echo "  Mapper:    http://localhost:8001/docs"
	@echo "  Calendar:  http://localhost:8003/docs"
	@echo "  Ingestor:  http://localhost:8004/docs"
	@echo ""
	@echo "Run 'make logs' to view logs or 'make status' to check health"

stop:
	@docker compose down

restart:
	@docker compose restart

status:
	@docker compose ps

logs:
	@docker compose logs -f

clean:
	@docker compose down -v --remove-orphans
	@echo "Cleaned up containers and volumes"

# =============================================================================
# INDIVIDUAL SERVICE COMMANDS
# =============================================================================

ui:
	@docker compose up -d ui
	@echo "UI started at http://localhost:3000"

chat:
	@docker compose up -d chat
	@echo "Chat API started at http://localhost:8005/docs"

mapper:
	@docker compose up -d mapper
	@echo "Mapper API started at http://localhost:8001/docs"

calendar:
	@docker compose up -d calendar
	@echo "Calendar API started at http://localhost:8003/docs"

ingestor:
	@docker compose up -d workout-ingestor
	@echo "Workout Ingestor started at http://localhost:8004/docs"

# =============================================================================
# PER-SERVICE LOGS
# =============================================================================

logs-ui:
	@docker compose logs -f ui

logs-chat:
	@docker compose logs -f chat

logs-mapper:
	@docker compose logs -f mapper

logs-calendar:
	@docker compose logs -f calendar

logs-ingestor:
	@docker compose logs -f workout-ingestor

.DEFAULT_GOAL := help
