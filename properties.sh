#!/bin/bash

# Set of properties for all scripts.
#
# Author: Andres Gomez
# Version: 2023-10-06

# Name of the Postgresql database to connect.
declare -r DBNAME=notes

# Mails to send the report.
declare -r EMAILS="${EMAILS:-angoca@yahoo.com}"

# Overpass interpreter.
declare -r OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

