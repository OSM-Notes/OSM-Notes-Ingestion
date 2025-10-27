#!/usr/bin/awk -f
# Extract note comments metadata from OSM XML to CSV format.
# Supports both Planet and API formats with auto-detection.
#
# Output format: note_id,sequence_action,event,created_at,id_user,username
# sequence_action is a counter starting from 1 for each note
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-27

BEGIN {
  comment_seq = 0
  in_note = 0
  in_comments = 0
  comment_date = ""
  comment_uid = ""
  comment_user = ""
  comment_action = ""
}

# Planet format: note tag with id attribute
/<note[^>]+id="/ {
  # Extract note ID and reset comment sequence counter
  if (match($0, /id="([^"]+)"/, m)) note_id = m[1]
  comment_seq = 0
  in_note = 0
  next
}

# API format: note tag without id attribute
/<note.*lat=/ {
  # Extract note ID will come from <id> sub-tag
  note_id = ""
  comment_seq = 0
  in_note = 1
  in_comments = 0
  next
}

# Extract note ID from API format
in_note && /^\s*<id>/ {
  if (match($0, /<id>([^<]+)<\/id>/, m)) note_id = m[1]
  next
}

# Track when we enter comments section (API format)
/^\s*<comments>/ {
  in_comments = 1
  comment_seq = 0
  next
}

# Track when we leave comments section (API format)
/^\s*<\/comments>/ {
  in_comments = 0
  next
}

# End of note tag (API format)
/^\s*<\/note>/ {
  in_note = 0
  in_comments = 0
  next
}

# Planet format: comment attributes
/<comment / {
  # Planet format: attributes in the comment tag
  comment_seq++
  
  if (match($0, /action="([^"]+)"/, m)) event = m[1]
  if (match($0, /timestamp="([^"]+)"/, m)) created_at = m[1]
  
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
  
  # Output CSV
  printf "%s,%s,%s,%s,%s,%s\n", note_id, comment_seq, event, created_at, id_user, username
  next
}

# API format: comment tag within comments section
in_comments && /^\s*<comment>/ {
  comment_seq++
  comment_date = ""
  comment_uid = ""
  comment_user = ""
  comment_action = ""
  next
}

# API format: extract comment date
in_comments && /^\s*<date>/ {
  if (match($0, /<date>([^<]+)<\/date>/, m)) comment_date = m[1]
  next
}

# API format: extract comment uid
in_comments && /^\s*<uid>/ {
  if (match($0, /<uid>([^<]+)<\/uid>/, m)) comment_uid = m[1]
  next
}

# API format: extract comment user
in_comments && /^\s*<user>/ {
  if (match($0, /<user>([^<]+)<\/user>/, m)) comment_user = m[1]
  next
}

# API format: extract comment action
in_comments && /^\s*<action>/ {
  if (match($0, /<action>([^<]+)<\/action>/, m)) comment_action = m[1]
  next
}

# API format: end of comment tag, output
in_comments && /^\s*<\/comment>/ {
  # Output CSV
  printf "%s,%s,%s,%s,%s,%s\n", note_id, comment_seq, comment_action, comment_date, comment_uid, comment_user
  
  # Reset for next comment
  comment_date = ""
  comment_uid = ""
  comment_user = ""
  comment_action = ""
  next
}

