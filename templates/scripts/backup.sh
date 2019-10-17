#!/bin/bash

# Copyright 2019 Google LLC
#
# This software is licensed under the Open Software License version
# 3.0. The full text of this license can be found in https://opensource.org/licenses/OSL-3.0
# or in the file LICENSE which is distributed along with the software.

# Backup data, code and files.
bin/magento setup:backup --code --db --media

# Displays the last backups.
bin/magento info:backups:list
