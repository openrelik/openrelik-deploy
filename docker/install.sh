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

# Exit early if there already is a 'openrelik' directory
if [ -d "openrelik" ]; then
  echo -e "\033[1;31m ⚠️  Error: Directory 'openrelik' already exists. Exiting.\033[0m\n"
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
echo -e "\033[1;34m[1/4] Setting up variables...\033[0m\c"
BASE_DEPLOY_URL="https://raw.githubusercontent.com/openrelik/openrelik-deploy/main/docker"
BASE_SERVER_URL="https://raw.githubusercontent.com/openrelik/openrelik-server/main"
STORAGE_PATH="\/usr\/share\/openrelik\/data\/artifacts"
POSTGRES_USER="openrelik"
POSTGRES_PASSWORD="$(generate_random_string)"
POSTGRES_SERVER="openrelik-postgres"
POSTGRES_DATABASE_NAME="openrelik"
RANDOM_SESSION_STRING="$(generate_random_string)"
RANDOM_JWT_STRING="$(generate_random_string)"
echo -e " ✅"

# Create dirs
echo -e "\033[1;34m[2/4] Creating necessary directories...\033[0m\c"
mkdir -p ./openrelik/{data/postgresql,data/artifacts,config}
echo -e " ✅"

# Set the current working directory
cd ./openrelik

# Fetch installation files
echo -e "\033[1;34m[3/4] Downloading configuration files...\033[0m\c"
curl -s ${BASE_DEPLOY_URL}/config.env > config.env
curl -s ${BASE_DEPLOY_URL}/docker-compose.yml > docker-compose.yml
curl -s ${BASE_SERVER_URL}/settings_example.toml > settings.toml
echo -e " ✅"

# Replace placeholder values in settings.toml
echo -e "\033[1;34m[4/4] Configuring settings...\033[0m\c"
replace_in_file "<REPLACE_WITH_STORAGE_PATH>" "${STORAGE_PATH}" "settings.toml"
replace_in_file "<REPLACE_WITH_POSTGRES_USER>" "${POSTGRES_USER}" "settings.toml"
replace_in_file "<REPLACE_WITH_POSTGRES_PASSWORD>" "${POSTGRES_PASSWORD}" "settings.toml"
replace_in_file "<REPLACE_WITH_POSTGRES_SERVER>" "${POSTGRES_SERVER}" "settings.toml"
replace_in_file "<REPLACE_WITH_POSTGRES_DATABASE_NAME>" "${POSTGRES_DATABASE_NAME}" "settings.toml"
replace_in_file "<REPLACE_WITH_RANDOM_SESSION_STRING>" "${RANDOM_SESSION_STRING}" "settings.toml"
replace_in_file "<REPLACE_WITH_RANDOM_JWT_STRING>" "${RANDOM_JWT_STRING}" "settings.toml"

# Move settings to the mapped folder.
mv settings.toml ./config/

# Replace placeholder values in config.env (for docker compose)
replace_in_file "<REPLACE_WITH_POSTGRES_USER>" "${POSTGRES_USER}" "config.env"
replace_in_file "<REPLACE_WITH_POSTGRES_PASSWORD>" "${POSTGRES_PASSWORD}" "config.env"
replace_in_file "<REPLACE_WITH_POSTGRES_DATABASE_NAME>" "${POSTGRES_DATABASE_NAME}" "config.env"

# Symlink the docker compose config
ln -s config.env .env
echo -e " ✅"

# We are done
echo -e "\n\033[1;32mInstallation Complete! 🎉\033[0m

\033[1mNext Steps:\033[0m

1. \033[1;34mSetup authentication:\033[0m
   * Instructions: https://openrelik.org/docs/getting-started/
   * Update \033[1mconfig/settings.toml\033[0m with your \033[1mclient_id\033[0m and \033[1mclient_secret\033[0m
   * Grant access to your gmail account by adding <USERNAME>@gmail.com to \033[1mallow_list in \033[1mconfig/settings.toml
2. \033[1;34mLaunch Containers:\033[0m docker compose up -d\n
3. \033[1;34mAccess OpenRelik at:\033[0m http://localhost:8711/\n"
