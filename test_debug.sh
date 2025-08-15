#!/bin/bash

# Test script to debug the issue with __checkPrereqs

# Source the functions
source bin/functionsProcess.sh

# Test the function directly
echo "Testing __checkPrereqs with invalid parameter..."
PROCESS_TYPE="--invalid"
__checkPrereqs
echo "Function returned with code: $?"

# Test the function with valid parameter
echo "Testing __checkPrereqs with valid parameter..."
PROCESS_TYPE="--base"
__checkPrereqs
echo "Function returned with code: $?"
