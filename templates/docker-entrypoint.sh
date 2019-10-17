#!/bin/bash

# Copyright 2019 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

# Supervisor config file location
CONFIG_FILES=(
    "/usr/local/etc/php-fpm.conf" \
    "/usr/local/etc/php/conf.d/zz-magento.ini" \
    "/etc/nginx/sites-enabled/magento" \
    "/etc/supervisor/conf.d/supervisor.conf" \
)

source /usr/local/bin/common_functions.sh

# Enable bash debug if DEBUG_DOCKER_ENTRYPOINT exists
if [[ "${DEBUG_DOCKER_ENTRYPOINT}" = "true" ]]; then
    echo "!!! WARNING: DEBUG_DOCKER_ENTRYPOINT is enabled!"
    echo "!!! WARNING: Use only for debugging. Do not use in production!"
    set -x
    env
fi

# Iterate over all the config files, as follows:
# PHP-FPM service, PHP-FPM - Magento related settings
# NGINX and Supervisor config
for FILE in ${CONFIG_FILES[@]}; do
    replace_magento_vars "${FILE}"
done

# Remove default nginx config
if [[ -f /etc/nginx/sites-enabled/default ]]; then
    rm -f /etc/nginx/sites-enabled/default
fi

# Install Magento and PHP Dependencies
# If it fails, breaks the execution
setup_magento.sh
if [[ "$?" -ne 0 ]]; then
    echo >&2 "Failure during Magento setup."
    exit 1
fi

# For security reasons, remove write permissions from these directories
if [[ -d /app/app/etc ]]; then
    chmod -f 664 -R /app/app/etc
fi

echo "Starting container..."
exec "$@"
