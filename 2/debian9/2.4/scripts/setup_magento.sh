#!/bin/bash
#
# Copyright 2019 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

set -eu

# Default values
: ${MAGENTO_MYSQL_DB:=magento}
: ${MAGENTO_ADMIN_USERNAME:=admin}
: ${MAGENTO_RUN_MODE:=production}

# Defines the list of all required fields to this script run properly
REQUIRED_FIELDS=( \
    "MAGENTO_MYSQL_HOST" \
    "MAGENTO_REDIS_HOST" \
    "MAGENTO_REDIS_PORT" \
    "MAGENTO_MYSQL_USERNAME" \
    "MAGENTO_MYSQL_PASSWORD" \
    "MAGENTO_REDIS_PASSWORD" \
    "MAGENTO_ADMIN_EMAIL" \
    "ENABLE_CRONJOBS"
)

source /usr/local/bin/common_functions.sh
source /usr/local/bin/setup_functions.sh


# 1. Preparing the installation ->

# Check if Magento is already installed
if [[ "$(is_magento_installed)" = "true" ]]; then
    echo "Magento is already installed."
    exit 0
fi

# If some field is not valid, quit
if [[ "$(validate_required_fields ${REQUIRED_FIELDS[@]})" != "true" ]]; then
    exit_with_error "Required fields are missing."
fi

# Check if password has been set, if not, generates a random one.
if [[ -z "${MAGENTO_ADMIN_PASSWORD:-}" ]]; then
    MAGENTO_ADMIN_PASSWORD=$(pwgen 10 1 | tr -d "\n")
    echo "New Admin Password has been generated."
    echo "Password: ${MAGENTO_ADMIN_PASSWORD}"
fi

# Await Redis and MySQL. Once both are up, the setup continues.
await_for_mysql_and_redis

# 2. Installing Magento ->

# Copy installation folder from built container to a volume folder
# This should be done, so installed Magento can be contained in a PVC
# in a K8S application
CURRENT_FOLDER="$(pwd)"
copy_installation_folder /magento "${CURRENT_FOLDER}" composer.json

# Install Magento and Magento database
install_magento

# Create first administrator user
create_admin_user

# 3. Preparing the production access ->

# Prepare Magento Database Indexes, cache cleaning and web wizard setup app
prepare_magento_for_production

echo "=================================="
echo " Magento Succesfully Installed"
echo "----------------------------------"
echo " Username: ${MAGENTO_ADMIN_USERNAME}"
echo " Password: ${MAGENTO_ADMIN_PASSWORD}"
echo "-> $(bin/magento info:adminuri| tr -d "\n")"
echo "=================================="
