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

function generate_random_string() {
  local charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local length=32
  openssl rand -base64 32 | tr -dc "$charset" | fold -w "$length" | head -n 1
}

# Create dirs
mkdir -p ./openrelik/{data/postgresql,data/artifacts,config}

# Set the working directory
cd ./openrelik

# Fetch installation files
curl -s https://raw.githubusercontent.com/openrelik/openrelik-deploy/main/docker/config.env > config.env
curl -s https://raw.githubusercontent.com/openrelik/openrelik-deploy/main/docker/docker-compose.yml > docker-compose.yml
curl -s https://raw.githubusercontent.com/openrelik/openrelik-server/main/settings_example.toml > settings.toml

STORAGE_PATH="\/usr\/share\/openrelik\/data\/artifacts"
POSTGRES_USER="openrelik"
POSTGRES_PASSWORD="$(generate_random_string)"
POSTGRES_SERVER="openrelik-postgres"
POSTGRES_DATABASE_NAME="openrelik"
RANDOM_SESSION_STRING="$(generate_random_string)"
RANDOM_JWT_STRING="$(generate_random_string)"

# Portable use of sed (BSD sed expects an argument after the -i flag, even if it's just an empty string.)
sed "s/<REPLACE_WITH_STORAGE_PATH>/${STORAGE_PATH}/g" settings.toml > settings.toml.tmp && mv settings.toml.tmp settings.toml
sed "s/<REPLACE_WITH_POSTGRES_USER>/${POSTGRES_USER}/g" settings.toml > settings.toml.tmp && mv settings.toml.tmp settings.toml
sed "s/<REPLACE_WITH_POSTGRES_PASSWORD>/${POSTGRES_PASSWORD}/g" settings.toml > settings.toml.tmp && mv settings.toml.tmp settings.toml
sed "s/<REPLACE_WITH_POSTGRES_SERVER>/${POSTGRES_SERVER}/g" settings.toml > settings.toml.tmp && mv settings.toml.tmp settings.toml
sed "s/<REPLACE_WITH_POSTGRES_DATABASE_NAME>/${POSTGRES_DATABASE_NAME}/g" settings.toml > settings.toml.tmp && mv settings.toml.tmp settings.toml
sed "s/<REPLACE_WITH_RANDOM_SESSION_STRING>/${RANDOM_SESSION_STRING}/g" settings.toml > settings.toml.tmp && mv settings.toml.tmp settings.toml
sed "s/<REPLACE_WITH_RANDOM_JWT_STRING>/${RANDOM_JWT_STRING}/g" settings.toml > settings.toml.tmp && mv settings.toml.tmp settings.toml

# Move settings to the mapped folder.
mv settings.toml ./config/

# Replace variables in config.env (for docker compose)
sed "s/<REPLACE_WITH_POSTGRES_USER>/${POSTGRES_USER}/g" config.env > config.env.tmp && mv config.env.tmp config.env
sed "s/<REPLACE_WITH_POSTGRES_PASSWORD>/${POSTGRES_PASSWORD}/g" config.env > config.env.tmp && mv config.env.tmp config.env
sed "s/<REPLACE_WITH_POSTGRES_DATABASE_NAME>/${POSTGRES_DATABASE_NAME}/g" config.env > config.env.tmp && mv config.env.tmp config.env

# Symlink the docker compose config
ln -s config.env .env

# We are done, let's celebrate with some emojis.
echo -e "
🎉 Installation complete! 🚀\n\n
➡️  Launch containers: docker compose up -d \n
🗝️  Secure with Google OAuth:\n
    1. Create credentials: \n
       https://developers.google.com/workspace/guides/create-credentials#oauth-client-id\n
    2. Update config/settings.toml with your client_id & client_secret\n
"
