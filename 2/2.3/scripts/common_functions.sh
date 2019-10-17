#!/bin/bash

# Responsible for replacing environment variables in a source file
# using envsubst
function replace_magento_vars() {
    local SOURCE_FILE="$1"
    local VARS="\$MAGENTO_RUN_MODE \$PHP_MEMORY_LIMIT \$PHP_UPLOAD_SIZE \$ENABLE_CRONJOBS"
    local TEMP_OUTPUT
    local RET_VAL

    # Check if source file exists
    if [[ ! -f ${SOURCE_FILE} ]]; then
        echo >&2 "File ${SOURCE_FILE} not found."
        exit 1
    fi

    # Replace variables from temp variable and
    # outputs to the source file
    TEMP_OUTPUT=$(cat ${SOURCE_FILE} | envsubst "${VARS}")
    echo -n "${TEMP_OUTPUT}" > "${SOURCE_FILE}"

    # If it fails, exit with error, otherwise exit with success.
    if [[ "$?" -ne 0 ]]; then
        exit_with_error "Error parsing file."
    fi
}


# Responsible for testing all required fields
# If at least one required field is missing, script should be aborted
# User should be notified about the missing fields
# Returns true if all fields are valid, otherwise false
#
# Examples:
# - Test with missing fields:
#
#   export FIRST_NAME="John"
#   export LAST_NAME=""
#   REQUIRED_FIELDS=(
#       "FIRST_NAME"
#       "LAST_NAME"
#       "AGE"
#   )
#   echo "Result is: $(validate_required_fields)"
#   # => Outputs:
#   The following fields are required:
#   - LAST_NAME
#   - AGE
#   Result is: false
#
# - Test with valid fields:
#
#   export FIRST_NAME="John"
#   export LAST_NAME="Doe"
#   export AGE=40
#   REQUIRED_FIELDS=(
#       "FIRST_NAME"
#       "LAST_NAME"
#       "AGE"
#   )
#   echo "Result is: $(validate_required_fields)"
#   # => Outputs:
#   Result is: true
function validate_required_fields() {
    local FIELDS_TO_VALIDATE=("$@")
    local FIELDS_NON_FILLED=()
    local FIELD_VALUE

    # Validates field by field and add to errors if it is not filled.
    for field in "${FIELDS_TO_VALIDATE[@]}"; do
        FIELD_VALUE=$(eval echo "\$$field")
        if [[ -z $FIELD_VALUE ]]; then
            FIELDS_NON_FILLED+=(${field})
        fi
    done

    # Exits if there are some missing field.
    if [[ ${#FIELDS_NON_FILLED[@]} -gt 0 ]]; then
        echo >&2 "The following fields are required:"
        for field in "${FIELDS_NON_FILLED[@]}"; do
            echo >&2 "- ${field}";
        done
        echo false
    else
        echo true
    fi
}

# Exit raising an error.
# Responsible for exit the function and send a message to stderr
# The function expects the message as the first parameter.
function exit_with_error() {
    echo >&2 $1
    if [[ -f bin/magento ]]; then
        bin/magento maintenance:disable
    fi
    exit 1
}
