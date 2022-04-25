#!/bin/bash
#
# Copyright 2019 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

set -e

# Ensure backup feature is enabled
bin/magento config:set system/backup/functionality_enabled 1 --quiet

# Backup data, code and files.
BKP_OUTPUT="$(bin/magento setup:backup --code --db --media  2>&1)"

# Gets the backup pathes from Magento CLI Output
# Filters only numbers, get the one which appears in first row
BACKUP_ID="$(echo ${BKP_OUTPUT} | grep -o -E "([0-9]*)" | nl | awk '{if ($1 == "1") print $2}')"

# Outputs to the end user
if [[ ! -z "${BACKUP_ID}" ]]; then
    echo "${BACKUP_ID}"
else
    echo "Failure backing up data."
    exit 1
fi

# Hiding error so the developer who is using backup.sh can
# get BACKUP_ID properly
bin/magento maintenance:disable 2>&1 > /dev/null
