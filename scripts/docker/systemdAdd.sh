#/bin/sh

projectName=$1
projectFile=$2
envFile=$3
composePath=$4

exampleUsage="Example usage: ./scripts/docker/systemdAdd.sh myProject \$PWD/docker-compose.yml \$PWD/.env \$PODMAN_COMPOSE_PROVIDER"

if [ -z "$projectName" ]; then
  echo "Missing docker/podman compose yaml project name"
  echo $exampleUsage
  exit 1
fi

if [ -z "$projectFile" ]; then
  echo "Missing docker/podman compose yaml project file (docker-compose.yml)"
  echo $exampleUsage
  exit 1
fi

if [ -z "$composePath" ]; then
  echo "Missing docker/podman executable path (example: /usr/local/bin/docker-compose) "
  echo $exampleUsage
  exit 1
fi

if [ -z "$envFile" ]; then
  echo "Missing .env file path"
  echo $exampleUsage
  exit 1
fi

projectFile=$(realpath $projectFile)
envFile=$(realpath $envFile)
composePath=$(realpath $composePath)

if [ -f "${projectFile}" ]; then
  echo "Installing project as service on SystemD '$projectFile'..."
else
  echo "Error: project file '${projectFile}' does not exist"
  echo $exampleUsage
  exit 1
fi

if [ -f "${composePath}" ]; then
  echo "Using '${composePath}'..."
else
  echo "Error: compose executable path '${composePath}' does not exist"
  echo $exampleUsage
  exit 1
fi


if [ -f "${envFile}" ]; then
  echo "Applying '$envFile' variables..."
else
  echo "Error: .env file '${envFile}' does not exist"
  echo $exampleUsage
  exit 1
fi


echo
echo "About to install, are you sure you want to continue?"

read -p "Press key to continue.. (Ctrl + C to abort)" -n1 -s
echo


echo "Installing '${projectName}'..."

serviceName=${projectName}
serviceFile=/etc/systemd/system/${serviceName}.service

podmanSocket=$(podman info --format '{{.Host.RemoteSocket.Path}}')
podmanSocketMount=$(dirname "$podmanSocket")

export DOCKER_HOST=unix://$(podman info --format '{{.Host.RemoteSocket.Path}}')
export PODMAN_COMPOSE_PROVIDER=${composePath}

scriptPath=$(dirname "$(realpath "$0")")

echo "Creating systemd service file '${serviceFile}'..."
echo
cat <<EOF | sudo tee ${serviceFile}
[Unit]
Description=Docker Compose Application Service
Wants=network-online.target
After=network-online.target
#Requires=podman.service
#RequiresMountsFor=${podmanSocketMount}
StartLimitIntervalSec=0
StartLimitBurst=0

[Service]
Type=simple
RemainAfterExit=yes
Environment=DOCKER_HOST=unix://$(podman info --format '{{.Host.RemoteSocket.Path}}')
Environment=PODMAN_COMPOSE_PROVIDER=$composePath
Environment=USER_NAME=$USER
Environment=ENV_FILE_PATH=$envFile
Environment=PROJECT_FILE_PATH=$projectFile
Environment=PODMAN_FILE_PATH=$(which podman)
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$scriptPath/compose.sh "up -d"
ExecStop=$scriptPath/compose.sh "down"
Restart=always
RestartSec=5min

[Install]
WantedBy=multi-user.target default.target
EOF

echo

echo "Enabling persistent execution beyond user session..."
loginctl enable-linger

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling and starting the service..."
systemctl enable ${serviceName}.service
#systemctl start ${serviceName}.service

echo "Service '${serviceName}' has been installed. Useful commands:"
echo
echo "    start:  systemctl start  ${serviceName}"
echo "    stop:   systemctl stop   ${serviceName}"
echo "    status: systemctl status ${serviceName}"
echo "    logs:   journalctl -u ${serviceName}"
echo 
echo "You should set 'KillUserProcesses=no' on '/etc/systemd/logind.conf'" 
echo " and run 'systemctl restart systemd-logind'"
echo

