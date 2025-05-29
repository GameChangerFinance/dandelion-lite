#!/bin/bash
set -x
# Load global environment variables
set -a
source .env_core
set +a

echo "NETWORK: ${CORE_NETWORK}"

echo "Services to process: ${SERVICES}"

# Accept arguments
type=$1
compile_enabled=$2

# Convert SERVICES into an array
IFS=',' read -ra SERVICE_LIST <<< "$SERVICES"

compose_files=()

# Populate array
for service in "${SERVICE_LIST[@]}"; do
    service=$(echo "$service" | xargs)  # Trim whitespace
    compose_files+=("-f" "./services/$service/docker-compose.yml")
done

case "$type" in
    up)
        echo "Starting $service..."
        echo "$file"
        docker compose -p ${CORE_PROJ_NAME} "${compose_files[@]}" up -d
        ;;
    down)
        echo "Stopping $service and removing orphans..."
        docker compose -p ${CORE_PROJ_NAME} "${compose_files[@]}" down --remove-orphans
        ;;
    compile)
        if [ "$compile_enabled" == "Y" ]; then
            echo "Compiling config for $service..."
            echo "SERVICE_NAME=$service" > ".env_$service.generated"
            echo "Generated .env_$service.generated and docker-compose_$service.yml (if needed)"
        fi
        ;;
    *)
        echo "Invalid type: $type. Use UP, DOWN, or COMPILE."
        exit 1
        ;;
esac