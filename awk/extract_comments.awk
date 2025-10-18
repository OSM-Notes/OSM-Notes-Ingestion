#!/usr/bin/awk -f
# Extract note comments metadata from OSM Planet XML to CSV format.
#
# Output format: note_id,sequence_action,event,created_at,id_user,username
# sequence_action is a counter starting from 1 for each note
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-18

BEGIN {
  comment_seq = 0
}

/<note / {
  # Extract note ID and reset comment sequence counter
  match($0, /id="([^"]+)"/, m) && (note_id = m[1])
  comment_seq = 0
}

/<comment / {
  # Increment sequence counter for this note
  comment_seq++
  
  # Extract comment attributes
  match($0, /action="([^"]+)"/, m) && (event = m[1])
  match($0, /timestamp="([^"]+)"/, m) && (created_at = m[1])
  
  # uid and user are optional (anonymous comments)
  if (match($0, /uid="([^"]+)"/, m)) {
    id_user = m[1]
  } else {
    id_user = ""
  }
  
  if (match($0, /user="([^"]+)"/, m)) {
    username = m[1]
  } else {
    username = ""
  }
  
  # Output CSV with PostgreSQL column names
  # Format: note_id,sequence_action,event,created_at,id_user,username
  printf "%s,%s,%s,%s,%s,%s\n", note_id, comment_seq, event, created_at, id_user, username
}

