# AmakaFlow Workspace

Workout content transformation and synchronization platform.

## Quick Start

```bash
# Setup
make setup

# Edit .env with your API keys
nano .env

# Start services
make start

# View logs
make logs
```

## Structure

```
amakaflow-dev-workspace/
├── docker-compose.yml       # Service orchestration
├── .env                     # Environment (gitignored)
├── Makefile                 # Dev commands
│
├── amakaflow-ui/            # UI repo (cloned)
├── workout-ingestor-api/    # Ingestor repo (cloned)
├── mapper-api/              # Mapper repo (cloned)
├── strava-sync-api/         # Strava repo (cloned)
├── calendar-api/            # Calendar repo (cloned)
├── garmin-sync-api/         # Garmin repo (cloned)
├── garmin-usb-fit-api/      # USB FIT repo (cloned)
│
└── ui → amakaflow-ui        # Symlink for docker-compose
    workout-ingestor-api → ... # Symlinks for docker-compose
    etc...
```

## Services

- **UI** (3000): React frontend
- **Ingestor** (8004): YouTube/OCR/text parsing
- **Mapper** (8001): Exercise normalization
- **Strava** (8000): Strava OAuth sync
- **Calendar** (8003): Calendar events
- **Garmin Sync** (8002): Garmin Connect (optional)
- **USB FIT** (8095): FIT file generation (optional)

## Development

```bash
make start    # Start all services
make stop     # Stop all services
make logs     # View logs
make restart  # Restart services
make clean    # Clean up everything
```

## Updating Services

```bash
# Update a specific service
cd workout-ingestor-api
git pull
cd ..
docker-compose build workout-ingestor
docker-compose restart workout-ingestor
```
