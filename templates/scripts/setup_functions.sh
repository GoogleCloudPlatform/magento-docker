#!/bin/bash
#
# Copyright 2019 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

# Responsible for checking if Magento is already installed inside the volume
# If Magento is installed, cron should be started based on configuration
# Then script is aborted.
function is_magento_installed() {
    if [[ -d /app/pub/setup ]]; then
        echo true
    else
        echo false
    fi
}

# Responsible for checking if a host and port are listening connections
# First parameter receives a host name
# Second parameter receives a port number
function await_for_host_and_port() {
    local HOST="$1"
    local PORT="$2"
    timeout --preserve-status 300 bash -c "until echo > /dev/tcp/${HOST}/${PORT}; do sleep 2; done"
    if [[ "$?" -ne 0 ]]; then
        exit 1
    fi
}

# Responsible for awaiting the dependencies to be ready
# MySQL, Redis and Elasticsearch should be available so the setup can start.
function await_for_dependencies() {
    echo "Awaiting MySQL to be ready..." >&2
    await_for_host_and_port "${MAGENTO_MYSQL_HOST}" "3306"

    echo "Awaiting Redis to be ready..." >&2
    await_for_host_and_port "${MAGENTO_REDIS_HOST}" "${MAGENTO_REDIS_PORT}"

    echo "Awaiting Elasticsearch to be ready..." >&2
    await_for_host_and_port "${MAGENTO_ELASTICSEARCH_HOST}" "${MAGENTO_ELASTICSEARCH_PORT}"
}

# Responsible for copying an entire folder to a destination
# The usage of this function here is to copy the installation folder
# from container to a volume folder.
# If volume folder has already Magento Setup scripts by pass it
# It receives three parameters:
# First parameter - source folder
# Second parameter - destination folder
# Third parameter - lock file. If the file exists, no folder  is copied.
function copy_installation_folder() {
    local FROM="$1"
    local TO="$2"
    local LOCK_FILE="$3"

    if [[ ! -f "${LOCK_FILE}" ]]; then
        echo "Magento not found in ${TO} - copying now..." >&2
        if [ "$(ls -A)" ]; then
            echo "WARNING: ${TO} is not empty. Data might be overwritten." >&2
        fi
        tar cf - --one-file-system -C "${FROM}" . | tar xf -
        echo "Magento has been successfully copied to ${TO}" >&2
    fi
}

# Responsible for installing Magento
function install_magento() {
    # Enable debugging if MAGENTO_RUN_MODE is not production.
    local DEBUG_MAGENTO="false"
    if [[ "${MAGENTO_RUN_MODE}" != "production" ]]; then
        echo "Debugging enabled." >&2
        DEBUG_MAGENTO="true"
    fi

    # Important: If you use Redis for more than one type of caching,
    # It is recommended that you assign them in different databases as follows:
    # - default caching database number to 0,
    # - page caching database number to 1,
    # - session storage database number to 2
    # https://devdocs.magento.com/guides/v2.4/config-guide/redis/redis-session.html

    # Prepare configuration
    bin/magento setup:config:set \
        --backend-frontname admin \
        --enable-debug-logging "${DEBUG_MAGENTO}" \
        --db-host "${MAGENTO_MYSQL_HOST}" \
        --db-name "${MAGENTO_MYSQL_DB}" \
        --db-user "${MAGENTO_MYSQL_USERNAME}" \
        --db-password "${MAGENTO_MYSQL_PASSWORD}" \
        --elasticsearch-host "${MAGENTO_ELASTISEARCH_HOST}" \
        --elasticsearch-port "${MAGENTO_ELASTISEARCH_PORT}" \
        --elasticsearch-enable-auth 1 \
        --elasticsearch-username "${MAGENTO_ELASTISEARCH_USERNAME}" \
        --elasticsearch-password "${MAGENTO_ELASTISEARCH_PASSWORD}" \
        --elasticsearch-index-prefix magento
        --db-engine mysql \
        --session-save redis \
        --session-save-redis-host "${MAGENTO_REDIS_HOST}" \
        --session-save-redis-port "${MAGENTO_REDIS_PORT}" \
        --session-save-redis-password "${MAGENTO_REDIS_PASSWORD}" \
        --session-save-redis-persistent-id sess-db0 \
        --session-save-redis-db 2 \
        --cache-backend redis \
        --cache-backend-redis-server "${MAGENTO_REDIS_HOST}" \
        --cache-backend-redis-db 0 \
        --cache-backend-redis-port "${MAGENTO_REDIS_PORT}" \
        --cache-backend-redis-password "${MAGENTO_REDIS_PASSWORD}" \
        --page-cache redis \
        --page-cache-redis-server "${MAGENTO_REDIS_HOST}" \
        --page-cache-redis-db 1 \
        --page-cache-redis-port "${MAGENTO_REDIS_PORT}" \
        --page-cache-redis-password "${MAGENTO_REDIS_PASSWORD}" \
        --no-interaction

    # Install components
    bin/magento setup:install && bin/magento setup:upgrade

    # Compile static assets
    bin/magento setup:static-content:deploy -f

    # Setup magento for accepting ssl
    bin/magento setup:store-config:set \
        --use-secure=1 \
        --use-secure-admin=1
}

# Responsible for creating the first admin user
# based on previously set variables
function create_admin_user() {
    # MAGENTO_ADMIN_USERNAME is being used intentionally in Admin First ans Last Names
    # so the Administrator User can be created using the less configurations as possible.
    bin/magento admin:user:create \
        --admin-user="${MAGENTO_ADMIN_USERNAME}" \
        --admin-password="${MAGENTO_ADMIN_PASSWORD}" \
        --admin-email="${MAGENTO_ADMIN_EMAIL}" \
        --admin-firstname="${MAGENTO_ADMIN_USERNAME}" \
        --admin-lastname="${MAGENTO_ADMIN_USERNAME}"
}

# Responsible for injecting a patch in Magento PHP entrypoint
# so website can be accessed immediately after the deployment.
function inject_patch_hostname() {
    local MAGENTO_ENTRYPOINT="/app/pub/index.php"
    local INCLUDE_FILE="/scripts/inc/hostname_fix"

    python /scripts/inject_hostname.py \
        --source "${MAGENTO_ENTRYPOINT}" \
        --include "${INCLUDE_FILE}"
}

# Responsible for enabling crontab or not
# If first parameter = true, Magento cron tabs are installed.
function install_magento_crontab() {
    local ENABLED="$1"

    if [[ "${ENABLED}" = "true" ]]; then
        # Apply Magento Crontab
        bin/magento cron:install --force
    fi
}

# Responsible for preparing Magento to run properly and
# without warnings.
# It reindexes the MySQL database, initilizes Redis databases
# cleans the cache and prepares web wizard setup
function prepare_magento_for_production() {
    # Reindex database
    bin/magento indexer:reindex

    # Clean cached data
    bin/magento cache:clean

    # Inject hostname fix. This is important so the user can access the website
    # exactly after the deployment
    inject_patch_hostname

    # Apply Magento crontab jobs
    install_magento_crontab "${ENABLE_CRONJOBS}"

    # Symbolic link to enable Setup App on Admin page.
    if [[ ! -f /app/pub/setup ]]; then
        ln -s /app/setup/ /app/pub/setup
    fi
}
