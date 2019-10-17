#!/bin/bash

# Copyright 2019 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

set -eu

EXTENSION_NAME="$1"

if [[ -z "${EXTENSION_NAME:-}" ]]; then
    echo >&2 "EXTENSION_NAME variable not provided."
    exit 1
fi

cd /app

# Install the extension
composer.phar require ${EXTENSION_NAME}

# Enable all pending extensions and update dependencies
bin/magento setup:upgrade

# Deploy static content
bin/magento setup:static-content:deploy -f

# Compile new dependencies added to the project
bin/magento setup:di:compile

# Clean cache
bin/magento cache:clean

# Restarts PHP so OPCache can get the new code downloaded
supervisorctl restart php
