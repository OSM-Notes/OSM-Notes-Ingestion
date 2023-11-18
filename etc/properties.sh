#!/bin/bash

# Set of properties for all scripts.
#
# Author: Andres Gomez
# Version: 2023-10-06

# OpenStreetMap API URL
# shellcheck disable=SC2034
declare -r OSM_API="https://api.openstreetmap.org/api/0.6"

# Name of the Postgresql database to connect.
# shellcheck disable=SC2034
declare -r DBNAME=notes

# Mails to send the report to.
declare -r EMAILS="${EMAILS:-user@mail.com}"

# OpenStreetMap Planet dump
# shellcheck disable=SC2034
declare -r PLANET="https://planet.openstreetmap.org"

# Overpass interpreter.
# shellcheck disable=SC2034
declare -r OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"
