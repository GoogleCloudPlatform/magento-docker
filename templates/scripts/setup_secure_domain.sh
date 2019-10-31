#!/bin/bash
#
# Copyright 2019 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

set -eu

DOMAIN_NAME="$1"

if [[ -z "${DOMAIN_NAME}" ]]; then
    echo >&2 "DOMAIN_NAME var should be provided."
    exit 1
fi

cd /app

bin/magento setup:store-config:set \
    --base-url-secure="https://${DOMAIN_NAME}/" \
    --use-secure=1 \
    --use-secure-admin=1

bin/magento cache:flush

echo "======================"
echo "URLs Configured."
echo "https://${DOMAIN_NAME}"
echo "======================"
