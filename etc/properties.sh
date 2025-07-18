#!/bin/bash

# Set of properties for all scripts. This file should be modified for specific
# customization.
#
# Author: Andres Gomez
# Version: 2025-07-17

# Name of the Postgresql database to connect.
# shellcheck disable=SC2034
declare -r DBNAME="notes"

# User to connect to the database.
# shellcheck disable=SC2034
declare -r DB_USER="notes"

# Mails to send the report about checking the differences between planet and database.
declare -r EMAILS="username@domain.com"

# OpenStreetMap API URL.
# shellcheck disable=SC2034
declare -r OSM_API="https://api.openstreetmap.org/api/0.6"

# OpenStreetMap Planet dump.
# shellcheck disable=SC2034
declare -r PLANET="https://planet.openstreetmap.org"

# Overpass interpreter. Used to download the contries and maritimes boundaries.
# shellcheck disable=SC2034
declare -r OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

# Wait between loops when downloading boundaries, to prevent "Too many
# requests".
# shellcheck disable=SC2034
declare -r SECONDS_TO_WAIT="30"

# Get location in processPlanet.
# Quantity of notes to process per loop, to get the location of the note.
# shellcheck disable=SC2034
declare -r LOOP_SIZE="10000"
