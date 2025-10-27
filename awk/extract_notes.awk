#!/usr/bin/awk -f
# Extract notes from OSM XML to CSV format.
# Supports both Planet and API formats with auto-detection.
#
# Output format: note_id,latitude,longitude,created_at,status,closed_at,id_country
# Status is calculated: 'close' if closed_at exists, 'open' otherwise
# (Note: PostgreSQL ENUM uses 'close', not 'closed')
# id_country is empty (NULL), filled later by PostgreSQL function
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-27

BEGIN {
  # State variables for API format parsing
  in_note = 0
  note_id = ""
  note_lat = ""
  note_lon = ""
  date_created = ""
  date_closed = ""
  status = ""
}

# Planet format: attributes in the note tag
/<note[^>]+id="/ {
  # Extract from attributes (Planet format)
  if (match($0, /id="([^"]+)"/, m)) note_id = m[1]
  if (match($0, /lat="([^"]+)"/, m)) note_lat = m[1]
  if (match($0, /lon="([^"]+)"/, m)) note_lon = m[1]
  if (match($0, /created_at="([^"]+)"/, m)) date_created = m[1]
  
  # closed_at is optional
  if (match($0, /closed_at="([^"]+)"/, m) && m[1] != "") {
    date_closed = m[1]
    status = "close"
  } else {
    date_closed = ""
    status = "open"
  }
  
  # Output CSV
  printf "%s,%s,%s,%s,%s,%s,\n", note_id, note_lat, note_lon, date_created, status, date_closed
  
  # Reset state
  in_note = 0
  note_id = ""
  note_lat = ""
  note_lon = ""
  date_created = ""
  date_closed = ""
  status = ""
  next
}

# API format: attributes on note tag start
/<note.*lat=/ {
  in_note = 1
  
  # Extract lat/lon from attributes
  if (match($0, /lat="([^"]+)"/, m)) note_lat = m[1]
  if (match($0, /lon="([^"]+)"/, m)) note_lon = m[1]
  next
}

# Extract note ID from sub-tag (API format)
in_note && /^\s*<id>/ {
  if (match($0, /<id>([^<]+)<\/id>/, m)) note_id = m[1]
  next
}

# Extract date_created from sub-tag (API format)
in_note && /^\s*<date_created>/ {
  if (match($0, /<date_created>([^<]+)<\/date_created>/, m)) date_created = m[1]
  next
}

# Extract status from sub-tag (API format)
in_note && /^\s*<status>/ {
  if (match($0, /<status>([^<]+)<\/status>/, m)) status = m[1]
  # Convert API status to PostgreSQL enum format
  if (status == "closed") status = "close"
  next
}

# Extract date_closed from sub-tag (API format)
in_note && /^\s*<date_closed>/ {
  if (match($0, /<date_closed>([^<]+)<\/date_closed>/, m)) date_closed = m[1]
  next
}

# End of note tag (API format) - output and reset
in_note && /^\s*<\/note>/ {
  # If status is empty, default to open
  if (status == "") status = "open"
  
  # Output CSV
  printf "%s,%s,%s,%s,%s,%s,\n", note_id, note_lat, note_lon, date_created, status, date_closed
  
  # Reset state
  in_note = 0
  note_id = ""
  note_lat = ""
  note_lon = ""
  date_created = ""
  date_closed = ""
  status = ""
  next
}
