#!/bin/bash
#
# Copyright 2019 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

set -e

source common_functions.sh

BACKUP_ID=$1
CODE_FILE="${BACKUP_ID}_filesystem_code.tgz"
MEDIA_FILE="${BACKUP_ID}_filesystem_media.tgz"
DB_FILE="${BACKUP_ID}_db.sql"

# Declare initial state of restore
IS_REQUEST_OK=0

echo "Setting store to maintenance mode..."
bin/magento maintenance:enable || exit_with_error "Unable to set the store to maintenance mode."

# Backup data, code and files.
bin/magento setup:rollback \
    --code-file "${CODE_FILE}" \
    --media-file "${MEDIA_FILE}" \
    --db-file "${DB_FILE}" \
    --no-interaction

# If backup has not been completed with success, fail script
if [[ "$?" -ne 0 ]]; then
    echo >&2 "Magento data restore has been failed."
    exit 1
fi

# After code restore, bin/magento has the execution permission revoked
chmod +x bin/magento

# Set the application out of maintenance
bin/magento maintenance:disable

# Flush cache data
bin/magento cache:clean && bin/magento cache:flush

#  Test magento
IS_REQUEST_OK=$(curl -I -L  http://localhost | grep "200" | wc -l)
if [[ ${IS_REQUEST_OK} -gt 0 ]]; then
    echo "Magento backup has been applied successfully."
else
    echo "Error during backup restore"
fi

# If store could not be accessed, send error status
if [[ ${IS_REQUEST_OK} -eq 0 ]]; then
    echo >&2 "Magento website is down."
    exit 1
fi
