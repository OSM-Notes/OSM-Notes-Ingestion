#!/bin/bash

# Mock logger for tests
# Author: Andres Gomez (AngocA)
# Version: 2025-07-28

# Mock logging functions for tests
log_debug() {
 echo "DEBUG: $*" >&2
}

log_info() {
 echo "INFO: $*" >&2
}

log_warn() {
 echo "WARN: $*" >&2
}

log_error() {
 echo "ERROR: $*" >&2
}

log_fatal() {
 echo "FATAL: $*" >&2
}

log_trace() {
 echo "TRACE: $*" >&2
}

# Mock logger setup function
__set_log_level() {
 local level="${1:-INFO}"
 echo "Mock logger set to level: ${level}" >&2
}

# Export functions for use in tests
export -f log_debug log_info log_warn log_error log_fatal log_trace __set_log_level
