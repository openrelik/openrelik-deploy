#!/bin/bash

# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cat << "EOF"

   ____                   _____      _ _ _
  / __ \                 |  __ \    | (_) |
 | |  | |_ __   ___ _ __ | |__) |___| |_| | __
 | |  | | '_ \ / _ \ '_ \|  _  // _ \ | | |/ /
 | |__| | |_) |  __/ | | | | \ \  __/ | |   <
  \____/| .__/ \___|_| |_|_|  \_\___|_|_|_|\_\
        | |
        |_|

EOF

# Exit early if there already is an 'openrelik' directory
if [ -d "openrelik" ]; then
  echo -e "\033[1;31m ⚠️  Error: Directory 'openrelik' already exists.\033[0m\n"
  exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo -e "\033[1;31m ⚠️  Error: Docker is not installed. Please install Docker before running this script.\033[0m"
  echo -e "     Follow \033[1mhttps://docs.docker.com/engine/install/\033[0m to install Docker Engine for your platform.\n"
  exit 1
fi

# Check if any Docker containers with "openrelik" in their name are running
running_containers=$(docker ps --format "{{.Names}}")
if grep -q "openrelik" <<< "$running_containers"; then
  echo -e "\n\033[1;31m ⚠️  Error: Containers with 'openrelik' in their name are already running.\033[0m"
  echo -e "\033[1;31m     Please stop these containers before proceeding.\033[0m\n"
  exit 1
fi

# Generates a random string of a specified length using characters from a defined set.
function generate_random_string() {
  local charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local length=32
  openssl rand -base64 32 | tr -dc "$charset" | fold -w "$length" | head -n 1
}

# This function replaces all occurrences of a search pattern within a specified file
# with a given replacement value. It ensures compatibility with both GNU and BSD
# versions of the 'sed' command.
replace_in_file() {
  local search_pattern="$1"
  local replacement_value="$2"
  local filename="$3"
  # Portable sed usage: handle both GNU and BSD sed
  if sed --version 2>&1 | grep -q GNU; then
    sed -i "s/${search_pattern}/${replacement_value}/g" "${filename}"
  else
    sed -i "" "s/${search_pattern}/${replacement_value}/g" "${filename}"
  fi
}

# Setup variables
echo -e "\033[1;34m[1/8] Setting up variables...\033[0m\c"
BASE_DEPLOY_URL="https://raw.githubusercontent.com/openrelik/openrelik-deploy/main/docker"
BASE_SERVER_URL="https://raw.githubusercontent.com/openrelik/openrelik-server/main"
STORAGE_PATH="\/usr\/share\/openrelik\/data\/artifacts"
POSTGRES_USER="openrelik"
POSTGRES_PASSWORD="$(generate_random_string)"
POSTGRES_SERVER="openrelik-postgres"
POSTGRES_DATABASE_NAME="openrelik"
RANDOM_SESSION_STRING="$(generate_random_string)"
RANDOM_JWT_STRING="$(generate_random_string)"
echo -e "\r\033[1;32m[1/8] Setting up variables... Done\033[0m"

# Create dirs
echo -e "\033[1;34m[2/8] Creating necessary directories...\033[0m\c"
mkdir -p ./openrelik/{data/postgresql,data/artifacts,config}
echo -e "\r\033[1;32m[2/8] Creating necessary directories... Done\033[0m"

# Set the current working directory
cd ./openrelik

# Fetch installation files
echo -e "\033[1;34m[3/8] Downloading configuration files...\033[0m\c"
curl -s ${BASE_DEPLOY_URL}/config.env > config.env
curl -s ${BASE_DEPLOY_URL}/docker-compose.yml > docker-compose.yml
curl -s ${BASE_DEPLOY_URL}/prometheus.yml > prometheus.yml
curl -s ${BASE_SERVER_URL}/settings_example.toml > settings.toml
echo -e "\r\033[1;32m[3/8] Downloading configuration files... Done\033[0m"

# Replace placeholder values in settings.toml
echo -e "\033[1;34m[4/8] Configuring settings...\033[0m\c"
replace_in_file "<REPLACE_WITH_STORAGE_PATH>" "${STORAGE_PATH}" "settings.toml"
replace_in_file "<REPLACE_WITH_POSTGRES_USER>" "${POSTGRES_USER}" "settings.toml"
replace_in_file "<REPLACE_WITH_POSTGRES_PASSWORD>" "${POSTGRES_PASSWORD}" "settings.toml"
replace_in_file "<REPLACE_WITH_POSTGRES_SERVER>" "${POSTGRES_SERVER}" "settings.toml"
replace_in_file "<REPLACE_WITH_POSTGRES_DATABASE_NAME>" "${POSTGRES_DATABASE_NAME}" "settings.toml"
replace_in_file "<REPLACE_WITH_RANDOM_SESSION_STRING>" "${RANDOM_SESSION_STRING}" "settings.toml"
replace_in_file "<REPLACE_WITH_RANDOM_JWT_STRING>" "${RANDOM_JWT_STRING}" "settings.toml"

# Move settings to the mapped folder.
mv settings.toml ./config/

# Move metrics config (prometheus.yml) to the mapped folder.
mkdir ./config/prometheus
mv prometheus.yml ./config/prometheus

# Create prometheus data directory and set the correct permissions/ownership.
mkdir -p ./data/prometheus
sudo chown -R 65534:65534 ./data/prometheus

# Replace placeholder values in config.env (for docker compose)
replace_in_file "<REPLACE_WITH_POSTGRES_USER>" "${POSTGRES_USER}" "config.env"
replace_in_file "<REPLACE_WITH_POSTGRES_PASSWORD>" "${POSTGRES_PASSWORD}" "config.env"
replace_in_file "<REPLACE_WITH_POSTGRES_DATABASE_NAME>" "${POSTGRES_DATABASE_NAME}" "config.env"

# Symlink the docker compose config
ln -s config.env .env
echo -e "\r\033[1;32m[4/8] Configuring settings... Done\033[0m"

# Starting containers
echo -e "\033[1;34m[5/8] Starting containers...\033[0m"
docker compose up -d --wait --quiet-pull --remove-orphans
echo -e "\r\033[1;32m[5/8] Starting containers... Done\033[0m"

# Wait for the server container to be ready
echo -e "\033[1;34m[6/8] Waiting for openrelik-server to be ready...\033[0m"
timeout=120
retry_interval=5
start_time=$(date +%s)
while true; do
  curl -s -o /dev/null "http://localhost:8710"
  # Exit and continue if curl returns 0 (success)
  if [[ $? -eq 0 ]]; then
    break
  fi

  elapsed_time=$(($(date +%s) - $start_time))
  if [[ $elapsed_time -ge $timeout ]]; then
    echo -e "\033[1;31m  ✗ Timeout waiting for openrelik-server to be ready.\033[0m"
    exit 1
  fi
  echo -e "\033[1;33m  ⏳ Waiting for openrelik-server... ($elapsed_time seconds)\033[0m"
  sleep $retry_interval
done
echo -e "\r\033[1;32m[6/8] Waiting for openrelik-server to be ready... Done\033[0m"

# Initialize the database
echo -e "\033[1;34m[7/8] Initializing database...\033[0m\c"
docker compose exec openrelik-server bash -c "(cd /app/openrelik/datastores/sql && alembic upgrade head)"
echo -e "\r\033[1;32m[7/8] Initializing database... Done\033[0m"

# Creating the admin user
echo -e "\033[1;34m[8/8] Createing admin user...\033[0m\c"
password=$(LC_ALL=C tr -dc 'A-Za-z0-9@%*+,-./' < /dev/urandom 2>/dev/null | head -c 16)
docker compose exec openrelik-server python admin.py create-user admin --password $password --admin 1>/dev/null
echo -e "\r\033[1;32m[8/8] Createing admin user... Done\033[0m"

# We are done
echo -e "\n\033[1;33mInstallation Complete! 🎉\033[0m

\033[1;34mLogin:\033[0m http://localhost:8711/
\033[1;34mUsername:\033[0m admin
\033[1;34mPassword:\033[0m $password\n"
