#!/bin/bash
#
# Copyright 2019 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

set -eu

source /usr/local/bin/common_functions.sh

cd /app

echo "Setting store to maintenance mode..."
bin/magento maintenance:enable || exit_with_error "Unable to set the store to maintenance mode."

echo "Upgrading PHP dependencies..."
composer.phar update || exit_with_error "Unable to update PHP dependencies."

echo "Upgrading Magento..."
bin/magento setup:upgrade || exit_with_error "Unable to upgrade Magento..."

echo "Compiling Magento code and extensions...\ "
php bin/magento setup:di:compile || exit_with_error "Unable to upgrade Magento..."

echo "Compiling static assets..."
bin/magento setup:static-content:deploy -f || exit_with_error "Unable to compile static assets."

echo "Cleaning the cache..."
bin/magento cache:clean || exit_with_error "Unable to clean the cache."

echo "Restarting PHP-FPM..."
supervisorctl restart php || exit_with_error "Unable to restart PHP-FPM."

echo "Disabling maintenance mode and enabling the store for all visitors..."
bin/magento maintenance:disable
echo "Magento has been updated successfully."
