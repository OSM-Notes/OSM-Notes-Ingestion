#!/bin/bash

# Mock functions for hybrid testing
# This file provides mock implementations of functions that require network access
# Author: Andres Gomez (AngocA)
# Version: 2025-01-20

# This file is sourced by the wrapper script BEFORE the real script loads its functions
# This allows us to override functions like __check_network_connectivity without modifying production code

# Mock __check_network_connectivity to always succeed in TEST_MODE
# This allows tests to run without requiring actual network connectivity
# The real function is in lib/osm-common/errorHandlingFunctions.sh
# By defining this function here, it will be available when the script sources errorHandlingFunctions.sh
# However, since the script sources errorHandlingFunctions.sh AFTER this wrapper is executed,
# we need to ensure this function is redefined AFTER the script loads its functions.
# 
# Solution: Create a modified version of errorHandlingFunctions.sh that checks TEST_MODE first
# OR: Ensure curl mock works correctly (which is the preferred approach)

# For now, this file serves as documentation of the approach
# The actual solution is to ensure the curl mock works correctly for connectivity checks
