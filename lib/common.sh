#!/bin/bash

# Utility library for logging, validation, and error handling

# Function for logging messages
log_message() {
    local message="\$1"
    echo "[\$(date +'%Y-%m-%d %H:%M:%S')] [INFO] \$message"
}

# Function for validation
validate_param() {
    local param="\$1"
    if [[ -z "\$param" ]]; then
        log_message "Parameter is missing: \$param"
        return 1
    fi
    return 0
}

# Function for error handling
handle_error() {
    local error_message="\$1"
    log_message "Error: \$error_message"
    exit 1
}
