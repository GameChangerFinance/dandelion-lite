#!/bin/bash

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

# Loop over specified services only
for service in "${SERVICE_LIST[@]}"; do
    # Trim whitespace (in case of spaces around commas)
    service=$(echo "$service" | xargs)

    file="docker-compose_$service.yml"
    env_file=".env_$service"

    if [ ! -f "$file" ]; then
        echo "Warning: $file not found. Skipping $service."
        continue
    fi

    # Load service-specific env
    if [ -f ".env_$service" ]; then
        source ".env_$service"
    else
        echo "Warning: .env_$service not found. Skipping $service."
        continue
    fi

    case "$type" in
        up)
            echo "Starting $service..."
            echo "$file"
            docker compose -p ${CORE_PROJ_NAME} -f "$file" --env-file $env_file up -d
            ;;
        down)
            echo "Stopping $service and removing orphans..."
            docker compose -p ${CORE_PROJ_NAME} -f "$file" --env-file $env_file down --remove-orphans
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

done
