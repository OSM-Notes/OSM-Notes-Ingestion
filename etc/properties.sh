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

# User to connect to the database
# shellcheck disable=SC2034
declare -r DB_USER=notes

# Mails to send the report to.
declare -r EMAILS="${EMAILS:-angoca@yahoo.com}"

# OpenStreetMap Planet dump
# shellcheck disable=SC2034
declare -r PLANET="https://planet.openstreetmap.org"

# Overpass interpreter.
# shellcheck disable=SC2034
declare -r OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

# Get location in processPlanet.
# Quantity of notes to process per loop, to get the location of the note.
declare -r LOOP_SIZE="${LOOP_SIZE:-10000}"
# Number of parallel threads to process notes to get the location.
declare -r PARALLELISM="${PARALLELISM:-5}"
