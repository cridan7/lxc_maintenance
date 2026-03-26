#!/bin/bash

# Structured logging functions for shell scripts

# Log level constants
INFO="INFO"
ERROR="ERROR"
DEBUG="DEBUG"

# Get current timestamp in UTC
get_timestamp() {
    date -u +"%Y-%m-%d %H:%M:%S"
}

# Log message function
log_message() {
    local level="$1"
    shift
    local message="$*"
    echo "$(get_timestamp) [$level] $message"
}

# Log info message
log_info() {
    log_message "$INFO" "$@"
}

# Log error message
log_error() {
    log_message "$ERROR" "$@"
}

# Log debug message
log_debug() {
    log_message "$DEBUG" "$@"
}

# Example usage
# log_info "This is an info message"
# log_error "This is an error message"
# log_debug "This is a debug message"