#!/bin/bash
# Local Docker development helper script
# Usage: ./docker-dev.sh [build|up|down|logs|seed|shell|clean]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="aviquest-api"
BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Commands
build() {
    log_info "Building Docker image..."
    docker-compose -f "$BACKEND_DIR/docker-compose.yml" build --no-cache
    log_info "Build complete!"
}

up() {
    log_info "Starting container..."
    docker-compose -f "$BACKEND_DIR/docker-compose.yml" up -d
    sleep 2
    log_info "Container started!"
    echo ""
    status
    echo ""
    log_info "API available at: http://localhost:8000"
    log_info "API docs at: http://localhost:8000/api/v1/docs"
    log_info "Health check: curl http://localhost:8000/health"
}

down() {
    log_info "Stopping container..."
    docker-compose -f "$BACKEND_DIR/docker-compose.yml" down
    log_info "Container stopped!"
}

logs() {
    log_info "Streaming logs (Ctrl+C to exit)..."
    docker-compose -f "$BACKEND_DIR/docker-compose.yml" logs -f api
}

logs_tail() {
    log_info "Last 50 lines of logs:"
    docker-compose -f "$BACKEND_DIR/docker-compose.yml" logs --tail=50 api
}

status() {
    log_info "Container status:"
    docker-compose -f "$BACKEND_DIR/docker-compose.yml" ps
}

seed() {
    log_info "Seeding database with birds..."
    docker-compose -f "$BACKEND_DIR/docker-compose.yml" exec -T api \
        python -m scripts.seed_birds
    log_info "Database seeded!"
}

shell() {
    log_info "Opening shell in container..."
    docker-compose -f "$BACKEND_DIR/docker-compose.yml" exec api /bin/bash
}

health() {
    log_info "Checking health endpoint..."
    if curl -s http://localhost:8000/health | python -m json.tool; then
        log_info "Health check passed!"
    else
        log_error "Health check failed!"
        return 1
    fi
}

clean() {
    log_warn "Removing container, volumes, and images..."
    docker-compose -f "$BACKEND_DIR/docker-compose.yml" down -v
    docker rmi aviquest-backend 2>/dev/null || true
    log_info "Cleanup complete!"
}

restart() {
    log_info "Restarting container..."
    down
    sleep 1
    up
}

test() {
    log_info "Running tests..."
    docker-compose -f "$BACKEND_DIR/docker-compose.yml" exec -T api \
        pytest tests/ -v
}

# Print help
help() {
    cat << EOF
AviQuest FastAPI Backend — Docker Development Helper

Usage: $(basename "$0") [command]

Commands:
    build       Build Docker image
    up          Start container (detached)
    down        Stop and remove container
    logs        Stream container logs (Ctrl+C to exit)
    tail        Show last 50 log lines
    status      Show container status
    health      Test health endpoint
    seed        Seed database with birds (for testing)
    shell       Open interactive shell in container
    test        Run pytest tests
    restart     Restart container
    clean       Remove containers, volumes, images
    help        Show this help message

Examples:
    # Local development workflow
    ./docker-dev.sh build
    ./docker-dev.sh up
    ./docker-dev.sh status
    ./docker-dev.sh logs
    ./docker-dev.sh health
    ./docker-dev.sh seed
    ./docker-dev.sh test
    ./docker-dev.sh down

    # Debugging
    ./docker-dev.sh shell
    ./docker-dev.sh tail

Environment:
    .env file is required. Copy from .env.example and customize:
        cp .env.example .env

API Documentation:
    Swagger UI: http://localhost:8000/api/v1/docs
    ReDoc: http://localhost:8000/api/v1/redoc
    Health: http://localhost:8000/health

EOF
}

# Main
case "${1:-help}" in
    build)
        build
        ;;
    up)
        up
        ;;
    down)
        down
        ;;
    logs)
        logs
        ;;
    tail)
        logs_tail
        ;;
    status)
        status
        ;;
    health)
        health
        ;;
    seed)
        seed
        ;;
    shell)
        shell
        ;;
    test)
        test
        ;;
    restart)
        restart
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        help
        exit 1
        ;;
esac
