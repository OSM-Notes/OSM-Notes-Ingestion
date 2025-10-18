#!/usr/bin/awk -f
# Extract notes from OSM Planet XML to CSV format.
#
# Output format: note_id,latitude,longitude,created_at,status,closed_at,id_country
# Status is calculated: 'close' if closed_at exists, 'open' otherwise
# (Note: PostgreSQL ENUM uses 'close', not 'closed')
# id_country is empty (NULL), filled later by PostgreSQL function
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-18

/<note / {
  # Extract attributes (assuming standard OSM order)
  match($0, /id="([^"]+)"/, m) && (id = m[1])
  match($0, /lat="([^"]+)"/, m) && (lat = m[1])
  match($0, /lon="([^"]+)"/, m) && (lon = m[1])
  match($0, /created_at="([^"]+)"/, m) && (created = m[1])
  
  # closed_at is optional
  if (match($0, /closed_at="([^"]+)"/, m) && m[1] != "") {
    closed = m[1]
    status = "close"
  } else {
    closed = ""
    status = "open"
  }
  
  # Output CSV with status column for PostgreSQL
  # Format: note_id,latitude,longitude,created_at,status,closed_at,id_country
  # (id_country is NULL, will be filled later by get_country function)
  printf "%s,%s,%s,%s,%s,%s,\n", id, lat, lon, created, status, closed
}

