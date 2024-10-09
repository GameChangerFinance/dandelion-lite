#!/usr/bin/env bash
# Global configuration
# shellcheck disable=SC1091,SC2015

docker() {
    podman "$@"
}
export -f docker

VERSION=0.0.2
NAME="dandoman"
# Get the full path of the current script's directory
script_dir=$(dirname "$(realpath "${BASH_SOURCE[@]}")")
# Remove the last folder from the path and rename it to KLITE_HOME
KLITE_HOME=$(dirname "$script_dir")
path_line="export PATH=\"$script_dir:\$PATH\""

# Append path_line to shell configuration files
append_path_to_shell_configs() {
  for file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$file" ] && ! grep -Fxq "$path_line" "$file"; then
      echo "$path_line" >> "$file"
    fi
  done
}

# Function definitions
install_dependencies() {
  [[ -f "./.dependency_installation_status" ]] && return 0

  os_name="$(uname -s)"
  case "${os_name}" in
    Linux*)
      source /etc/os-release
      case "${ID}" in
        ubuntu|debian)
          if ! sudo apt update && sudo apt install -y gpg curl gawk; then return 1; fi
          if ! sudo mkdir -p /etc/apt/keyrings; then return 1; fi
          if [[ ! -f /etc/apt/keyrings/charm.gpg ]] && ! curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg; then return 1; fi
          if ! echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list; then return 1; fi
          if ! sudo apt-get update || ! sudo apt install -y gum; then return 1; fi
          ;;
        fedora|rhel)
          if ! sudo dnf install curl awk;  then return 1; fi
          arch=$(uname -m)
          if [ "$arch" = "x86_64" ]; then
            if ! curl -L https://github.com/charmbracelet/gum/releases/download/v0.13.0/gum-0.13.0-1.x86_64.rpm -o gum.rpm || ! sudo dnf install -y ./gum.rpm; then return 1; fi
          elif [ "$arch" = "aarch64" ]; then
            if ! curl -L https://github.com/charmbracelet/gum/releases/download/v0.13.0/gum-0.13.0-1.aarch64.rpm -o gum.rpm || ! sudo dnf install -y ./gum.rpm; then return 1; fi
            return 1
          else
            echo "Unsupported architecture."
            return 1
          fi
          ;;
        arch|manjaro)
          if ! sudo pacman -Syu curl awk gum; then return 1; fi
          ;;
        alpine)
          if ! sudo apk add curl awk gum; then return 1; fi
          ;;
        *)
          echo "Unsupported Linux distribution for automatic installation."
          return 1
          ;;
      esac
      ;;
    Darwin*)
      if ! brew install curl awk gum; then return 1; fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      if ! winget install curl awk gum; then return 1; fi
      ;;
    *)
      echo "Unsupported operating system."
      return 1
      ;;
  esac

  touch "./.dependency_installation_status"
  echo "Dependencies installed successfully."
}


# Check Docker function
check_docker() {
  # Check if docker or podman (aliasing docker) command is available and outputs a version
  docker_version=$(docker --version 2>/dev/null | grep "version")
  if [ -z "${docker_version}" ]; then
    echo -e "\nDocker or Podman not installed.\n"
    if gum confirm --unselected.foreground 231 --unselected.background 39 --selected.bold --selected.background 121 --selected.foreground 231 "Would you like to install Podman now?"; then
      podman_install
    elif gum confirm --unselected.foreground 231 --unselected.background 39 --selected.bold --selected.background 121 --selected.foreground 231 "Would you like to install Docker now?"; then
      docker_install      
    else    
      return 1
    fi
  # Check if Docker is running by executing a test container
  else
    # Check if Docker is running
    if ! docker run --rm hello-world > /dev/null 2>&1; then
      echo -e "\nDocker is not running.\n"
      if gum confirm --unselected.foreground 231 --unselected.background 39 --selected.bold --selected.background 121 --selected.foreground 231 "Would you like to try starting Docker now?"; then
        echo "Attempting to start Docker..."
        # Starting Docker based on OS
        os_name="$(uname -s)"
        case "${os_name}" in
          Linux*)
            gum spin --spinner dot --title "Starting Docker..." -- echo && sudo systemctl start docker
            ;;
          Darwin*)
            gum spin --spinner dot --title "Starting Docker..." -- Open -a Docker
            ;;
          *)
            echo "Cannot start Docker automatically on this OS."                  
            return 1
            ;;
        esac
        # Recheck if Docker starts successfully
        sleep 30  # Wait a bit before rechecking
        if ! docker info > /dev/null 2>&1; then
          echo -e "\nFailed to start Docker.\n"
          return 1
        else
          echo "Docker started successfully."
        fi
      else
        return 1
      fi
    fi
  fi
  # echo "Docker is running."
  return 0
}

docker_status(){
  # Prepare the Docker status message
  docker_status=$(if check_docker; then
    gum style --foreground 121 --margin 1 "🐳 ${docker_version} Installed and Working"
  else  
    echo "🐳 🔻";
  fi)
  # Function to check the status of a Docker container
  check_container_status() {
    local container_name="$1"
    local up_icon="$2"
    local down_icon="$3"
    if [[ -n $(docker ps -qf "name=${container_name}" 2>/dev/null) ]]; then
      if docker ps -f "name=${container_name}" | grep -q -e '(unhealthy)' -e '(health: ' ; then
        echo "${up_icon} $(gum style --foreground 160 " ${container_name}" 2>/dev/null) $(gum style --bold --foreground 160 " UP (unhealthy)" 2>/dev/null)";
      else
        echo "${up_icon} $(gum style --foreground 121 " ${container_name}" 2>/dev/null) $(gum style --bold --foreground 121 " UP" 2>/dev/null)";
      fi
    else
      echo "${down_icon} $(gum style --foreground 160 " ${container_name}" 2>/dev/null) $(gum style --faint --foreground 160 " DOWN" 2>/dev/null)";
    fi
  }

  # Check for specific Docker containers
  node_container=$(check_container_status "cardano-node" "🧊 " "🔻 ")
  postgres_container=$(check_container_status "postgress" "🔹 " "🔻 ")
  db_sync_container=$(check_container_status "cardano-db-sync" "🥽 " "🔻 ")
  postgrest_container=$(check_container_status "postgrest" "🪢 " "🔻 ")
  haproxy_container=$(check_container_status "haproxy" "🧢 " "🔻 ")

  # Combine elements into one layout
  combined_layout=$(gum join --vertical --align center\
    "$docker_status " \
    "$node_container" \
    "$postgres_container " \
    "$db_sync_container " \
    "$postgrest_container " \
    "$haproxy_container " \
    "$(echo)")

  gum style \
    --border none \
    --border-foreground 121 \
    --margin "1 0" \
    --padding "0 10" \
    --background black \
    --foreground 121 \
    "$combined_layout"    
}


# Check Podman function
check_podman() {
  # Check if podman command is available and outputs a version
  docker_version=$(docker --version 2>/dev/null | grep "podman version")
  if [ -z "${docker_version}" ]; then
    echo -e "\Podman not installed.\n"
    if gum confirm --unselected.foreground 231 --unselected.background 39 --selected.bold --selected.background 121 --selected.foreground 231 "Would you like to install Podman now?"; then
      #docker_install
      podman_install
    else
      return 1
    fi
  # Check if Podman is running by executing a test container
  else
    # Check if Podman is running
    if ! docker run --rm hello-world > /dev/null 2>&1; then
      echo -e "\Podman is not running.\n"
      if gum confirm --unselected.foreground 231 --unselected.background 39 --selected.bold --selected.background 121 --selected.foreground 231 "Would you like to try starting Podman now?"; then
        echo "Attempting to start Podman..."
        # Starting Docker based on OS
        os_name="$(uname -s)"
        case "${os_name}" in
          Linux*)
            gum spin --spinner dot --title "Starting Podman..." -- echo && sudo systemctl --user enable --now podman.socket
            ;;
          Darwin*)
            gum spin --spinner dot --title "Starting Podman..." -- && echo "TODO" && exit 1
            ;;
          *)
            echo "Cannot start Podman automatically on this OS."                  
            return 1
            ;;
        esac
        # Recheck if Docker starts successfully
        sleep 30  # Wait a bit before rechecking
        if ! docker info > /dev/null 2>&1; then
          echo -e "\nFailed to start Podman.\n"
          return 1
        else
          echo "Podman started successfully."
        fi
      else
        return 1
      fi
    fi
  fi
  # echo "Podman is running."
  return 0
}


# Podman Install function
podman_install() {
  # Check if Podman was already installed
  if command -v podman > /dev/null 2>&1 && command -v docker > /dev/null 2>&1 && docker-compose-v2 -v > /dev/null 2>&1 && docker compose -v > /dev/null 2>&1 ; then
    echo "Podman and Podman aliasing for Docker and Docker Compose V2 seems already installed."
    return 0
  fi
  
  os_name="$(uname -s)"
  case "${os_name}" in
    Linux*)
      source /etc/os-release
      case "${ID}" in
        ubuntu|debian)
          # Add Docker's official GPG key:
          sudo apt-get update
          sudo apt-get install -y curl podman podman-docker        
          gum spin --spinner dot --title "Installing Podman..." -- echo
          curl -LO https://github.com/docker/compose/releases/download/v2.28.1/docker-compose-linux-x86_64
          chmod +x docker-compose-linux-x86_64
          sudo mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose-v2
          systemctl --user enable --now podman.socket
          echo "# Start: Podman setup" >> ~/.bash_profile
          echo "export DOCKER_HOST=unix://\$(podman info --format '{{.Host.RemoteSocket.Path}}')" >> ~/.bash_profile
          echo "alias docker=podman" >> ~/.bash_profile
          echo "export PODMAN_COMPOSE_PROVIDER=/usr/local/bin/docker-compose-v2" >> ~/.bash_profile
          echo "# End: Podman  setup" >> ~/.bash_profile
          source ~/.bash_profile
          sudo touch /etc/containers/nodocker
          docker -v 
          docker-compose-v2 -v
          ;;
        fedora|rhel)
          gum spin --spinner dot --title "Installing Podman..." -- echo && echo "TODO" && exit 1
          ;;
        arch|manjaro)
          gum spin --spinner dot --title "Installing Podman..." -- echo && echo "TODO" && exit 1
          ;;
        alpine)
          gum spin --spinner dot --title "Installing Podman..." -- echo && echo "TODO" && exit 1
          ;;
        *)
          echo "Unsupported Linux distribution for Podman installation."
          return 1
          ;;
      esac
      # Done
      ;;
    Darwin*)
      echo "TODO" && exit 1
      ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "For Windows, please install Podman Desktop manually."
      return 1
      ;;
    *)
      echo "Unsupported operating system."
      return 1
      ;;
  esac
}


# Docker Install function
docker_install() {
  # Check if Docker was already installed
  if command -v docker > /dev/null 2>&1 && docker compose version > /dev/null 2>&1 ; then
    echo "Docker is already installed."
    return 0
  fi

  os_name="$(uname -s)"
  case "${os_name}" in
    Linux*)
      source /etc/os-release
      case "${ID}" in
        ubuntu|debian)
          # Add Docker's official GPG key:
          sudo apt-get update
          sudo apt-get install -y ca-certificates curl gpg
          sudo install -m 0755 -d /etc/apt/keyrings
          curl -fsSL https://download.docker.com/linux/"${ID}"/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
          sudo chmod a+r /etc/apt/keyrings/docker.gpg
          # Add the repository to Apt sources:
          echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
          gum spin --spinner dot --title "Updating..." -- sudo apt-get update
          gum spin --spinner dot --title "Installing Docker..." -- echo && sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
          ;;
        fedora|rhel)
          gum spin --spinner dot --title "Installing Docker..." -- echo && sudo dnf -y install dnf-plugins-core && sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/dockerce.repo && sudo dnf install dockerce dockerce-cli containerd.io
          ;;
        arch|manjaro)
          gum spin --spinner dot --title "Installing Docker..." -- echo && sudo pacman -Syu docker
          ;;
        alpine)
          gum spin --spinner dot --title "Installing Docker..." -- echo && sudo apk add docker
          ;;
        *)
          echo "Unsupported Linux distribution for automatic Docker installation."
          return 1
          ;;
      esac
      # Add current user to docker group
      if sudo usermod -aG docker "${USER}"; then
        clear
        echo "User '${USER}' successfully added to the 'docker' group."
        echo "For the changes to take effect, kindly log out and then log back in. This will ensure the user is correctly assigned to the new group. After doing so, please re-execute this script."
        exit 0  # Exit the script successfully
      else
        echo "Error: Failed to add user '${USER}' to the 'docker' group."
        exit 1  # Exit the script with an error status
      fi
      ;;
    Darwin*)
      gum spin --spinner dot --title "Installing Docker..." -- brew install --cask docker
      # Add current user to docker group
      if sudo dscl . create /Groups/docker && sudo dseditgroup -o edit -a "${USER}" -t user docker; then
        clear
        echo "User '${USER}' successfully added to the 'docker' group."
        echo "For the changes to take effect, kindly log out and then log back in. This will ensure the user is correctly assigned to the new group. After doing so, please re-execute this script."
        exit 0  # Exit the script successfully
      else
        echo "Error: Failed to add user '$USER' to the 'docker' group."
        exit 1  # Exit the script with an error status
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "For Windows, please install Docker Desktop manually."
      return 1
      ;;
    *)
      echo "Unsupported operating system."
      return 1
      ;;
  esac

  # Starting Docker service based on OS
  os_name="$(uname -s)"
  case "${os_name}" in
  Linux*)
    if gum spin --spinner dot --title "Starting Docker..." -- echo && sudo systemctl start docker; then
      echo "Docker installed and started successfully."
    else
      echo "Failed to start Docker on Linux."
      return 1
    fi
    ;;
  Darwin*)
    if gum spin --spinner dot --title "Starting Docker..." -- Open -a Docker; then
      echo "Docker installed and started successfully."
    else
      echo "Failed to start Docker on macOS."
      return 1
    fi
    ;;
  *)
    echo "Cannot start Docker automatically on this OS."
    return 1
    ;;
  esac
}

# Function to check and create or copy .env file
check_env_file() {
  if [ ! -f ".env" ]; then  # Check if .env does not exist
	show_splash_screen
	action=$(gum choose --height 15 --item.foreground 39 --cursor.foreground 121 "Setup a Cardano Mainnet Network Node" "Setup a Cardano Pre-Production Network Node" )
	case "$action" in
		"Setup a Cardano Mainnet Network Node")
			cp .env.example.mainnet .env  # Copy .env.example to .env
			echo ".env file created from .env.example.mainnet ... please inspect the .env file and adjust variables (e.g. network) accordingly"
			read -p "Press key to continue.." -n1 -s

		;;
		"Setup a Cardano Pre-Production Network Node")
			cp .env.example.preprod .env  # Copy .env.example to .env
			echo ".env file created from .env.example.preprod ... please inspect the .env file and adjust variables (e.g. network) accordingly"
			read -p "Press key to continue.." -n1 -s
		;;
	esac
  fi
}

# Function to reset .env file
reset_env_file() {
  if [ -f ".env" ]; then  # Check if .env  
    if gum confirm --unselected.foreground 231 --unselected.background 39 --selected.bold --selected.background 121 --selected.foreground 231 "Are you sure you want to reset the .env file?"; then
      backup_name=".env.$(date +%Y%m%d%H%M%S)"  # Create a backup name with timestamp
      mv .env "$backup_name"  # Move .env to backup
      echo "Reset .env file. Backup created: $backup_name"
    else
      echo "Reset cancelled."
    fi
  else
    echo "No .env file to reset. Creating a new one with defaults..." 
    cp .env.example .env  # Copy .env.example to.env
  fi
}

# Function to handle .env file (create or edit)
handle_env_file() {
  if [ ! -f ".env" ]; then
    echo "Creating new .env file..."
    touch .env
  fi
  while true; do
    action=$(gum choose --height 15 --item.foreground 39 --cursor.foreground 121 "Add Entry" "Edit Entry" "Remove Entry" "View File" "Reset Config" "$(gum style --foreground 208 "Back")")
    case "$action" in
      "Add Entry")
        key=$(gum input --placeholder "Enter key")
        value=$(gum input --placeholder "Enter value")
        # Check if key or value is empty
        if [[ -z "$key" || -z "$value" ]]; then
          echo "Key or value cannot be empty. Entry not added."
        else
          printf "%s=%s\n" "$key" "$value" >> .env
          clear
          gum style --border rounded --border-foreground 121 --padding "1" --margin "1" --foreground green "Current .env content:" "$(cat "${KLITE_HOME}"/.env)"
        fi
        ;;
      "Edit Entry")
        line_to_edit="$(gum filter < "${KLITE_HOME}"/.env)"
        key=$(echo "$line_to_edit" | cut -d '=' -f 1)
        existing_value=$(echo "$line_to_edit" | cut -d '=' -f 2-)
        # Check if key is empty
        if [[ -z "$key" ]]; then
          echo "No key selected for editing."
        else
          new_value=$(gum input --placeholder "Enter new value for $key")
          # Check if new value is empty or the same as the existing value
          if [[ -z "$new_value" ]]; then
            echo "New value cannot be empty. Entry not edited."
          elif [[ "$new_value" == "$existing_value" ]]; then
            echo "New value is the same as the existing value. Entry not edited."
          else
            sed -i '' "s/^$key=.*/$key=$new_value/" .env
          fi
        fi
        ;;
      "Remove Entry")
          line_to_remove="$(gum filter < "${KLITE_HOME}"/.env)"
          key_to_remove=$(echo "$line_to_remove" | cut -d '=' -f 1)
          if [[ -z "$key_to_remove" ]]; then
            echo "No key selected for removal."
          else
            # Remove the line from .env file
            sed -i '' "/^$key_to_remove=/d" .env
            clear
            gum style --border rounded --border-foreground 121 --padding "1" --margin "1" --foreground green "Current .env content:" "$(cat "${KLITE_HOME}"/.env)"
          fi
          ;;
      "View File")
          clear
          gum style --border rounded --border-foreground 121 --padding "1" --margin "1" --foreground green "Current .env content:" "$(cat "${KLITE_HOME}"/.env)"
          ;;
      "Reset Config")
          # Logic for reset config
          reset_env_file
          ;;
      "Back")
          show_splash_screen
          break
          ;;
    esac
  done
}

# Menu function with improved UI and submenus
menu() {
    while true; do
        choice=$(gum choose --height 15 --item.foreground 121 --cursor.foreground 39 "Tools" "Docker" "Setup" "Advanced" "Config" "$(gum style --foreground 160 "Exit")")

        case "$choice" in
            "Tools")
            setup_choice=$(gum choose --height 15 --cursor.foreground 229 --item.foreground 39 "$(gum style --foreground 87 "gLiveView")" "$(gum style --foreground 87 "cntools")"  "$(gum style --foreground 117 "Enter PSQL")" "$(gum style --foreground 117 "DBs Lists")" "$(gum style --foreground 117 "Expose with NGROK")" "$(gum style --foreground 208 "Back")")
            case "$setup_choice" in
                "gLiveView")
                    # Find the Docker container ID with 'postgres' in the name
                    container_id=$(docker ps -qf "name=cardano-node")
                    if [ -z "$container_id" ]; then
                        echo "No running Node container found."
                        read -r -p "Press enter to continue"
                    else
                        # Executing commands in the found container
                        docker exec -it "$container_id" bash -c "/opt/cardano/cnode/scripts/gLiveView.sh"
                    fi
                    show_splash_screen           
                    ;;
                "cntools")
                    # Find the Docker container ID with 'postgres' in the name
                    container_id=$(docker ps -qf "name=cardano-node")
                    if [ -z "$container_id" ]; then
                        echo "No running Node container found."
                        read -r -p "Press enter to continue"
                    else
                        # Executing commands in the found container
                        docker exec -it "$container_id" bash -c "/opt/cardano/cnode/scripts/cntools.sh"
                    fi
                    show_splash_screen           
                    ;;
                "Enter PSQL")
                    # Logic for Enter Postgres
                    container_id=$(docker ps -qf "name=postgress")
                    if [ -z "$container_id" ]; then
                        echo "No running PostgreSQL found."
                        read -r -p "Press enter to continue"
                    else
                        # Executing commands in the found container
                        docker exec -it "$container_id" bash -c "/usr/bin/psql -U $POSTGRES_USER -d $POSTGRES_DB"
                    fi
                    show_splash_screen
                    ;;
                "DBs Lists")
                    # Logic for Enter Postgres
                    container_id=$(docker ps -qf "name=postgress")
                    if [ -z "$container_id" ]; then
                        echo "No running PostgreSQL found."
                        read -r -p "Press enter to continue"
                    else
                        # Executing commands in the found container
                        docker exec -it -u postgres "$container_id" bash -c "/scripts/klTablesAndIndexes.sh" > scripts/TablesAndIndexesList.txt
                        echo "TablesAndIndexesList.txt File created in your script folder."
                    fi
                    show_splash_screen
                    ;;
                "Expose with NGROK")
                    # Logic for Enter Postgres
                    container_id=$(docker ps -qf "name=haproxy")
                    if [ -z "$container_id" ]; then
                        echo "No running Haproxy found."
                        read -r -p "Press enter to continue"
                    else
                        ./scripts/deploy/ngrok.sh                        
                    fi
                    show_splash_screen
                    ;;
                    
            esac
            ;;

            "Setup")
              # Submenu for Setup with plain text options
              setup_choice=$(gum choose --height 15 --cursor.foreground 229 --item.foreground 39 "Initialise Postgres" "Reset Postgres" "Full Backup" "Full Restore" "Run on system start"  "$(gum style --foreground 208 "Back")")

              case "$setup_choice" in
                #"Initialise Cardano Node")
                #    # Find the Docker container ID with 'postgres' in the name
                #    container_id=$(docker ps -qf "name=cardano-node")
                #    if [ -z "$container_id" ]; then
                #        echo "No running Node container found."
                #    else
                #        # Executing commands in the found container
                #        docker exec "$container_id" bash -c "/scripts/lib/install_cardano_node.sh"
                #    fi
                #    show_splash_screen                
                #    ;;
                "Initialise Postgres")
                  # Logic for installing Postgres
		  container_id=$(docker ps -qf "name=${PROJ_NAME}-postgress")
                  if [ -z "$container_id" ]; then
                    echo "No running PostgreSQL container found."
                    read -r -p "Press enter to continue"
                  else
                    read -p "Press key to continue.. (Ctrl + C to abort)" -n1 -s
                    echo
                    # Executing commands in the found container
                    docker exec "$container_id" bash -c "/scripts/lib/install_postgres.sh"
                    read -r -p "Press enter to continue"
                  fi
                  show_splash_screen
                  ;;
                  
                "Reset Postgres")
                  # Logic for installing Postgres
		  container_id=$(docker ps -qf "name=${PROJ_NAME}-postgress")
                  if [ -z "$container_id" ]; then
                    echo "No running PostgreSQL container found."
                    read -r -p "Press enter to continue"
                  else
                    read -p "Press key to continue.. (Ctrl + C to abort)" -n1 -s
                    echo
                    # Executing commands in the found container
                    docker exec "$container_id" bash -c "/scripts/lib/reset_postgres.sh"
                    read -r -p "Press enter to continue"
                  fi
                  show_splash_screen
                  ;;

                "Full Backup")
		  backupDir=${BACKUP_DIR:-$(pwd)}
		  ./scripts/docker/full-backup.sh "${PROJ_NAME}_" "${backupDir}"
                  read -r -p "Press enter to continue"
		  show_splash_screen
                  ;;
                "Full Restore")
		  backupDir=${BACKUP_DIR:-$(pwd)}
		  ./scripts/docker/full-restore.sh "${PROJ_NAME}_" "${backupDir}"
		  read -r -p "Press enter to continue"
                  show_splash_screen
                  ;;
		"Run on system start")
		  ./scripts/docker/systemdAdd.sh ${PROJ_NAME} docker-compose.yml .env $PODMAN_COMPOSE_PROVIDER
		  read -r -p "Press enter to continue"
                  show_splash_screen
                  ;;
		#"Initialise Dbsync")
                #    # Logic for installing Dbsync
                #    container_id=$(docker ps -qf "name=${PROJ_NAME}-cardano-db-sync")
                #    docker exec "$container_id" bash -c "/scripts/lib/install_dbsync.sh"
                #    ;;
                #"Initialise PostgREST")
                #    # Logic for installing PostgREST
                #    container_id=$(docker ps -qf "name=${PROJ_NAME}-postgrest")
                #    if [ -z "$container_id" ]; then
                #        echo "No running PostgreSQL container found."
                #    else
                #        # Executing commands in the found container
                #        docker exec "$container_id" bash -c "echo ECCO; echo basta"
                #        docker exec "$container_id" bash -c "/scripts/lib/install_postgrest.sh"
                #    fi
                #    show_splash_screen
                #    ;;
                #"Initialise HAProxy")
                #    # Logic for installing HAProxy
                #    container_id=$(docker ps -qf "name=${PROJ_NAME}-haproxy")
                #    if [ -z "$container_id" ]; then
                #        echo "No running PostgreSQL container found."
                #    else
                #        # Executing commands in the found container
                #        docker exec "$container_id" bash -c "/scripts/lib/install_haproxy.sh"
                #    fi
                #    show_splash_screen
                #    ;;
                "Back")
                  # Back to Main Menu
                  ;;
              esac
              ;;

              "$(gum style --foreground green "Docker")")
              # Submenu for Docker
              Docker_choice=$(gum choose --height 15 --item.foreground 39 --cursor.foreground 121 \
                "Docker Status" \
                "Docker Up/Reload" \
                "Docker Down" \
                "$(gum style --foreground 208 "Back")")

              case "$Docker_choice" in
                "Docker Status")
                    # Logic for Docker Status
                    clear
                    show_splash_screen
                    docker_status
                    # gum style --border rounded --border-foreground 121 --padding "1" --margin "1" --foreground 121 "$(docker compose ps | awk '{print $4, $8}')"
                    ;;
                "Docker Up/Reload")
                    # Logic for Docker Up
                    clear
                    show_splash_screen
                    gum spin --spinner dot --spinner.bold --show-output --title.align center --title.bold --spinner.foreground 121 --title.foreground 121  --title "Koios Lite Starting services..." -- echo && docker compose -f "${KLITE_HOME}"/docker-compose.yml up -d --remove-orphans
                    ;;
                "Docker Down")
                    # Logic for Docker Down
                    clear
                    show_splash_screen
                    gum spin --spinner dot --spinner.bold --show-output --title.align center --title.bold --spinner.foreground 202 --title.foreground 202 --title "Koios Lite Stopping services..." -- echo && docker compose -f "${KLITE_HOME}"/docker-compose.yml down
                    ;;
                "Back")
                    # Back to Main Menu
                    ;;
              esac
              ;;

            "Config")
              # Submenu for Config
              handle_env_file
              ;;

            "Advanced")
              setup_choice=$(gum choose --height 15 --cursor.foreground 229 --item.foreground 39 "$(gum style --foreground 82  "Enter Cardano Node")" "$(gum style --foreground 85  "Logs Cardano Node")" "$(gum style --foreground 82 "Enter Postgres")" "$(gum style --foreground 85 "Logs Postgres")" "$(gum style --foreground 82 "Enter Dbsync")" "$(gum style --foreground 85 "Logs Dbsync")" "$(gum style --foreground 85 "Logs PostgREST")" "$(gum style --foreground 82 "Enter HAProxy")" "$(gum style --foreground 85 "Logs HAProxy")" "$(gum style --foreground 82 "Enter Ogmios")" "$(gum style --foreground 85 "Logs Ogmios")" "$(gum style --foreground 85 "Logs Unimatrix")" "$(gum style --foreground 160 "REMOVE Postgres DB Volume")" "$(gum style --foreground 208 "Back")")
              case "$setup_choice" in
                "Enter Cardano Node")
                  # Enter
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-cardano-node")
                  if [ -z "$container_id" ]; then
                    echo "No running Node container found."
                    read -r -p "Press enter to continue"
                  else
                    # Executing commands in the found container
                    docker exec -it "$container_id" bash -c "bash"
                  fi
                  show_splash_screen                  
                  ;;
                "Logs Cardano Node")
                  # Enter
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-cardano-node")
                  if [ -z "$container_id" ]; then
                    echo "No running Node container found."
                    read -r -p "Press enter to continue"
                  else
                    # Logs
                    docker logs "$container_id" | more
                    read -r -p "End of logs reached, press enter to continue"
                  fi
                  show_splash_screen                  
                  ;;
                "Enter Postgres")
                  # Logic for Enter Postgres
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-postgress")
                  if [ -z "$container_id" ]; then
                    echo "No running PostgreSQL container found."
                    red -p "Press enter to continue"
                  else
                    # Executing commands in the found container
                    docker exec -it "$container_id" bash -c "bash"
                  fi
                  show_splash_screen
                  ;;
                "Logs Postgres")
                  # Logic for Enter Postgres
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-postgress")
                  if [ -z "$container_id" ]; then
                    echo "No running PostgreSQL container found."
                    read -r -p "Press enter to continue"
                  else
                    # Logs
                    docker logs "$container_id" | more
                    read -r -p "End of logs reached, press enter to continue"
                  fi
                  show_splash_screen
                  ;;
                "Enter Dbsync")
                  # Logic for Enter Dbsync
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-cardano-db-sync")
                  if [ -z "$container_id" ]; then
                    echo "No running Dbsync container found."
                    read -r -p "Press enter to continue"
                  else
                    # Executing commands in the found container
                    docker exec -it "$container_id" bash -c "bash"
                  fi
                  show_splash_screen
                  ;;
                "Logs Dbsync")
                  # Logic for Enter Dbsync
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-cardano-db-sync")
                  if [ -z "$container_id" ]; then
                    echo "No running Dbsync container found."
                    read -r -p "Press enter to continue"
                  else
                    # Logs
                    docker logs "$container_id" | more
                    read -r -p "End of logs reached, press enter to continue"
                  fi
                  show_splash_screen
                  ;;
                "Logs PostgREST")
                  # Logic for Enter PostgREST
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-postgrest")
                  if [ -z "$container_id" ]; then
                    echo "No running PostgREST container found."
                    read -r -p "Press enter to continue"
                  else
                    # Logs
                    docker logs "$container_id" | more
                    read -r -p "End of logs reached, press enter to continue"
                  fi
                  show_splash_screen
                  ;;
                "Enter HAProxy")
                  # Logic for Enter HAProxy
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-haproxy")
                  if [ -z "$container_id" ]; then
                    echo "No running HAProxy container found."
                    read -r -p "Press enter to continue"
                  else
                    # Executing commands in the found container
                    docker exec -it "$container_id" bash -c "bash"
                  fi
                  show_splash_screen
                  ;;
                "Logs HAProxy")
                  # Logic for Enter HAProxy
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-haproxy")
                  if [ -z "$container_id" ]; then
                    echo "No running HAProxy container found."
                    read -r -p "Press enter to continue"
                  else
                    # Logs
                    docker logs "$container_id" | more
                    read -r -p "End of logs reached, press enter to continue"
                  fi
                  show_splash_screen
                  ;;
                "Enter Ogmios")
                  # Logic for Enter Ogmios
                  service_name="ogmios"
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-${service_name}")
                  if [ -z "$container_id" ]; then
                    echo "No running Ogmios container found."
                    read -r -p "Press enter to continue"
                  else
                    # Executing commands in the found container
                    docker exec -it "$container_id" bash -c "bash"
                  fi
                  show_splash_screen
                  ;;
                "Logs Ogmios")
                  # Logic for Logs Ogmios
                  service_name="ogmios"
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-${service_name}")
                  if [ -z "$container_id" ]; then
                    echo "No running Ogmios container found."
                    read -r -p "Press enter to continue"
                  else
                    # Logs
                    docker logs "$container_id" | more
                    read -r -p "End of logs reached, press enter to continue"
                  fi
                  show_splash_screen
                  ;;
                "Logs Unimatrix")
                  # Logic for Logs Ogmios
                  service_name="unimatrix"
                  container_id=$(docker ps -qf "name=${PROJ_NAME}-${service_name}")
                  if [ -z "$container_id" ]; then
                    echo "No running Unimatrix container found."
                    read -r -p "Press enter to continue"
                  else
                    # Logs
                    docker logs "$container_id" | more
                    read -r -p "End of logs reached, press enter to continue"
                  fi
                  show_splash_screen
                  ;;
                "REMOVE Postgres DB Volume")
                  # Logic for Remove Postgres DB Volume
                  postgress_container_id=$(docker ps -qf "name=${PROJ_NAME}-postgress")
                  if [ -z "$postgress_container_id" ]; then

                    dbsync_container_id=$(docker ps -qf "name=${PROJ_NAME}-cardano-db-sync")
                    if [ -z "$dbsync_container_id" ]; then
                      echo "REMOVING Postgres DB Volume..."
                      docker volume rm ${PROJ_NAME}_postgresdb
                      read -r -p "Press enter to continue"
                    else
                      echo "Running Dbsync container found. Down all containers first."
                      read -r -p "Press enter to continue"
                    fi

                  else
                    # Logs
                    echo "Running Postgres DB container found. Down all containers first."
                    read -r -p "Press enter to continue"
                  fi
                  show_splash_screen
                  ;;
              esac
              ;;

            "Exit")
              clear
              echo "Thanks for using Dandelion Lite Node."
              exit 0  # Exit the menu loop
              ;;
        esac
    done
}

# Enhanced display UI function using gum layout
display_ui() {
  install_dependencies || { echo "Failed to install dependencies."; exit 0; }

  show_splash_screen
  # Wait for gum style commands to complete
  menu
}

about(){
  gum style --foreground 121 --border-foreground 121 --align center "$(gum join --vertical \
    "$(show_splash_screen)" \
    "$(gum style --align center --width 50 --margin "1 2" --padding "2 2" 'About: ' ' Dandelion Lite Node administration tool. (Based on Koios Lite) ')" \
    "$(gum style --align center --width 50 'https://github.com/koios-official/Lite-Node')")"
}

show_splash_screen(){
  # Clear the screen before displaying UI
  clear
  combined_layout1=$(gum style --foreground 121 --align center "$(cat ./scripts/.logo)")

  combined_layout2=$(gum join --horizontal \
    "$(gum style --bold --align center "${NODE_NAME:-'???'} | ")" \
    "$(gum style --faint --foreground 229 --align center "${PROJ_NAME:-'???'}")" \
    "$(gum style --faint --foreground 121 --align center " | - $NAME v$VERSION")")

  combined_layout=$(gum join --vertical \
    "$combined_layout1 " \
    "$combined_layout2")

  # Display the combined layout with a border
  gum style \
    --border none \
    --border-foreground 121 \
    --margin "1" \
    --padding "1 2" \
    --background black \
    --foreground 121 \
    "$combined_layout"

}

display_help_usage() {
  echo "Dandelion Lite Administration Tool Help Menu:"
  echo -e "------------------------------------\n"
  echo -e "Welcome to the Dandelion Lite Administration Tool Help Menu.\n"
  echo -e "Below are the available commands and their descriptions:\n"
  echo -e "--about: \t\t\t Displays information about the Koios administration tool."
  echo -e "--install-dependencies: \t Installs necessary dependencies."
  echo -e "--check-docker: \t\t Checks if Docker is running."
  echo -e "--handle-env-file: \t\t Manage .env file."
  echo -e "--reset-env: \t\t\t Resets the .env file to defaults."
  echo -e "--docker-status: \t\t Shows the status of Docker containers."
  echo -e "--docker-up: \t\t\t Starts Docker containers defined in docker-compose.yml."
  echo -e "--docker-down: \t\t\t Stops Docker containers defined in docker-compose.yml."
  echo -e "--enter-node: \t\t\t Accesses the Cardano Node container."
  echo -e "--logs-node: \t\t\t Displays logs for the Cardano Node container."
  echo -e "--gliveview: \t\t\t Executes gLiveView in the Cardano Node container."
  echo -e "--cntools: \t\t\t Runs CNTools in the Cardano Node container."
  echo -e "--enter-postgres: \t\t Accesses the Postgres container."
  echo -e "--logs-postgres: \t\t Displays logs for the Postgres container."
  echo -e "--enter-dbsync: \t\t Accesses the DBSync container."
  echo -e "--logs-dbsync: \t\t\t Displays logs for the DBSync container."
  echo -e "--enter-haproxy: \t\t Accesses the HAProxy container."
}

# Function to process command line arguments
process_args() {
  case "$1" in
    --about)
      about
      show_ui=false
      ;;
    --install-dependencies)
      rm -f ./.dependency_installation_status 
      install_dependencies && echo -e "\nDone!!\n"
      ;;
    --check-docker)
      check_docker
      ;;
    --docker-install)
      docker_install
      ;;
    --check-podman)
      check_podman
      ;;      
    --podman-install)
      podman_install
      ;;      
    --handle-env-file)
      handle_env_file
      ;;
    --reset-env)
      reset_env_file
      ;;
    --docker-status)
      docker_status
      ;;
    --docker-up)
      docker compose -f "${KLITE_HOME}"/docker-compose.yml up -d
      ;;
    --docker-down)
      docker compose -f "${KLITE_HOME}"/docker-compose.yml down
      ;;
    --enter-node)
      container_id=$(docker ps -qf "name=cardano-node")
      [ -z "$container_id" ] && echo "No running Node container found." || docker exec -it "$container_id" bash
      ;;
    --logs-node)
      container_id=$(docker ps -qf "name=cardano-node")
      [ -z "$container_id" ] && echo "No running Node container found." || docker logs "$container_id" | more
      ;;
    --gliveview)
      container_id=$(docker ps -qf "name=cardano-node")
      [ -z "$container_id" ] && echo "No running Node container found." || docker exec -it "$container_id" /opt/cardano/cnode/scripts/gLiveView.sh
      ;;
    --cntools)
      container_id=$(docker ps -qf "name=cardano-node")
      [ -z "$container_id" ] && echo "No running Node container found." || docker exec -it "$container_id" /opt/cardano/cnode/scripts/cntools.sh
      ;;
    --enter-postgres)
      execute_in_container "postgress" "bash"
      ;;
    --logs-postgres)
      show_logs "postgress"
      ;;
    --enter-dbsync)
      execute_in_container "${PROJ_NAME}-cardano-db-sync" "bash"
      ;;
    --logs-dbsync)
      show_logs "${PROJ_NAME}-cardano-db-sync"
      ;;
    --enter-haproxy)
      execute_in_container "${PROJ_NAME}-haproxy" "bash"
      ;;
    --logs-haproxy)
      show_logs "${PROJ_NAME}-haproxy"
      ;;
    --help|-h)
      display_help_usage
      ;;
    *)
      # Check if the number of arguments is zero
      if [ $# -eq 0 ]; then
        check_env_file
        display_ui  # Call the display function
      else
        echo "Unknown command: '$1'"
        echo "Use --help to see available commands."
        sleep 3
      fi
      ;;
  esac
}

execute_in_container() {
  local container_name=$1
  local command=$2
  local container_id;container_id=$(docker ps -qf "name=${container_name}")
  if [ -z "$container_id" ]; then
    echo "No running ${container_name} container found."
  else
    docker exec -it "${container_id}" "${command}"
  fi
}

show_logs() {
  local container_name=$1
  local container_id;container_id=$(docker ps -qf "name=${container_name}")
  if [ -z "${container_id}" ]; then
    echo "No running ${container_name} container found."
  else
    docker logs "$container_id" | more
  fi
}

# To find the right color's code
show_colors(){
  for i in {0..255}; do
    printf "\e[38;5;${i}m%3d\e[0m " "${i}"
    if (( (i + 1) % 16 == 0 )); then
      echo
    fi
  done
}

# Main function to orchestrate script execution
main() {
  append_path_to_shell_configs
  cd "$KLITE_HOME" || exit
  source .env
  process_args "$@"  # Process any provided command line arguments
  # install_dependencies || { echo "Failed to install dependencies."; exit 0; }
  if [ "$show_ui" = true ]; then
    display_ui
  fi
  #show_colors
}

# Execute the main function
main "$@"
