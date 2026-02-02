---
name: amakaflow-dev-environment-setup
description: Start, stop, and manage the AmakaFlow development environment including all APIs (chat, mapper, calendar, workout-ingestor) and the UI. Use when the user wants to run the dev environment, start services, check status, or troubleshoot the local stack.
category: devops
color: green
displayName: AmakaFlow Dev Environment
userInvocable: true
---

# AmakaFlow Dev Environment Manager

Manage the local development environment for AmakaFlow, including all backend APIs and the frontend UI.

## Services Overview

| Service | Port | Description | Health Check |
|---------|------|-------------|--------------|
| UI | 3000 | React/Vite frontend | http://localhost:3000 |
| Chat API | 8005 | AI conversation service | http://localhost:8005/health |
| Mapper API | 8001 | Exercise mapping service | http://localhost:8001/health |
| Calendar API | 8003 | Calendar integration | http://localhost:8003/health |
| Workout Ingestor | 8004 | Video/OCR ingestion | http://localhost:8004/health |

## When Invoked

### 1. Check Prerequisites

First, verify Docker is running and the environment is configured:

```bash
# Check Docker is available
docker --version && docker info > /dev/null 2>&1 && echo "Docker is running" || echo "ERROR: Docker is not running"

# Check .env file exists
test -f .env && echo ".env file exists" || echo "WARNING: .env file missing - run 'make setup' first"
```

### 2. Start All Services

To start the full development environment:

```bash
# Start all services in detached mode
docker compose up -d

# Or use make
make start
```

### 3. Verify Services Are Healthy

After starting, verify all services are running and healthy:

```bash
# Check container status
docker compose ps

# Wait for health checks and verify each service
echo "Checking service health..."

# Function to check health endpoint
check_health() {
  local name=$1
  local url=$2
  local max_attempts=30
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if curl -sf "$url" > /dev/null 2>&1; then
      echo "  $name: OK"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  echo "  $name: FAILED (timeout)"
  return 1
}

check_health "Chat API" "http://localhost:8005/health"
check_health "Mapper API" "http://localhost:8001/health"
check_health "Calendar API" "http://localhost:8003/health"
check_health "Workout Ingestor" "http://localhost:8004/health"
```

### 4. Display Access URLs

Once services are healthy, provide the user with access URLs:

```
Services are ready!

URLs:
  UI:              http://localhost:3000
  Chat API Docs:   http://localhost:8005/docs
  Mapper API Docs: http://localhost:8001/docs
  Calendar Docs:   http://localhost:8003/docs
  Ingestor Docs:   http://localhost:8004/docs

Commands:
  View logs:       make logs
  Stop services:   make stop
  Service status:  make status
```

## Common Operations

### Stop All Services
```bash
docker compose down
# or
make stop
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f chat
docker compose logs -f mapper
docker compose logs -f calendar
docker compose logs -f workout-ingestor
docker compose logs -f ui
```

### Restart a Single Service
```bash
docker compose restart chat
docker compose restart mapper
```

### Rebuild After Code Changes
```bash
# Rebuild specific service
docker compose build chat --no-cache
docker compose up -d chat

# Rebuild all
docker compose build --no-cache
docker compose up -d
```

### Check Service Status
```bash
docker compose ps
# or
make status
```

## Troubleshooting

### Service Won't Start

1. **Check logs for errors:**
   ```bash
   docker compose logs <service-name>
   ```

2. **Verify .env file has required keys:**
   ```bash
   grep -E "SUPABASE_URL|OPENAI_API_KEY|ANTHROPIC_API_KEY" .env
   ```

3. **Check port conflicts:**
   ```bash
   lsof -i :3000 -i :8001 -i :8003 -i :8004 -i :8005
   ```

### Health Check Failing

1. **Check if container is running:**
   ```bash
   docker compose ps
   ```

2. **Check container logs:**
   ```bash
   docker compose logs --tail=50 <service-name>
   ```

3. **Test health endpoint directly:**
   ```bash
   curl -v http://localhost:8005/health
   ```

### Out of Memory / Slow Performance

1. **Check Docker resource usage:**
   ```bash
   docker stats --no-stream
   ```

2. **Restart Docker daemon** if needed

3. **Clean up unused resources:**
   ```bash
   docker system prune -f
   ```

### Port Already in Use

1. **Find process using the port:**
   ```bash
   lsof -i :<port>
   ```

2. **Kill the process or change the port in docker-compose.yml**

## Environment Variables

Required environment variables in `.env`:

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anonymous key |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key |
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `CLERK_PUBLISHABLE_KEY` | Clerk auth publishable key |
| `CLERK_DOMAIN` | Clerk domain |

Optional:

| Variable | Description |
|----------|-------------|
| `HELICONE_API_KEY` | Helicone observability (optional) |
| `ELEVENLABS_API_KEY` | Text-to-speech (optional) |

## Quick Reference

| Task | Command |
|------|---------|
| Start all | `make start` or `docker compose up -d` |
| Stop all | `make stop` or `docker compose down` |
| View logs | `make logs` or `docker compose logs -f` |
| Status | `make status` or `docker compose ps` |
| Rebuild | `make build` or `docker compose build --no-cache` |
| Clean up | `make clean` or `docker compose down -v` |
| Help | `make help` |
