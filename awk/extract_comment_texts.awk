#!/usr/bin/awk -f
# Extract note comment texts from OSM XML to CSV format.
# Supports both Planet and API formats with auto-detection.
# Handles multiline text and HTML entities.
#
# Output format: note_id,sequence_action,"body",part_id
# sequence_action is a counter starting from 1 for each note
# part_id is empty (NULL) - used by Planet partitions
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-12

BEGIN {
  in_comment = 0
  comment_text = ""
  comment_seq = 0
  in_note = 0
  in_comments = 0
  in_text = 0
}

# Planet format: note tag with id attribute
/<note[^>]+id="/ {
  # Extract note ID and reset sequence counter
  if (match($0, /id="([^"]+)"/, m)) note_id = m[1]
  comment_seq = 0
  in_note = 0
  next
}

# API format: note tag without id attribute
/<note.*lat=/ {
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
  in_text = 0
  next
}

# End of note tag (API format)
/^\s*<\/note>/ {
  in_note = 0
  in_comments = 0
  in_text = 0
  next
}

# Planet format: comment attributes
/<comment / {
  # Increment sequence counter for this note
  comment_seq++
  
  # Check if comment is on single line or multiline
  if (match($0, /<comment[^>]*>(.+)<\/comment>/, content)) {
    # Single line comment
    text = content[1]
    
    # Decode HTML entities
    gsub(/&lt;/, "<", text)
    gsub(/&gt;/, ">", text)
    gsub(/&quot;/, "\"", text)
    gsub(/&apos;/, "'", text)
    gsub(/&amp;/, "\\&", text)  # Must be last to avoid double-decoding
    
    # Escape quotes for CSV (double them)
    gsub(/"/, "\"\"", text)
    
    # Trim whitespace
    gsub(/^[ \t]+|[ \t]+$/, "", text)
    
    # Output CSV
    printf "%s,%s,\"%s\",\n", note_id, comment_seq, text
  } else if (match($0, /<comment[^>]*>(.*)/, content)) {
    # Multiline comment start
    in_comment = 1
    comment_text = content[1]
  }
  next
}

# API format: comment tag within comments section
in_comments && /^\s*<comment>/ {
  comment_seq++
  in_comment = 0
  in_text = 0
  comment_text = ""
  next
}

# API format: extract text (handle both single-line and multiline)
in_comments && /^\s*<text>/ {
  # Check if text is on single line
  if (match($0, /<text>(.+)<\/text>/, m)) {
    # Single line text
    text = m[1]
    
    # Decode HTML entities
    gsub(/&lt;/, "<", text)
    gsub(/&gt;/, ">", text)
    gsub(/&quot;/, "\"", text)
    gsub(/&apos;/, "'", text)
    gsub(/&amp;/, "\\&", text)
    
    # Escape quotes for CSV
    gsub(/"/, "\"\"", text)
    
    # Trim whitespace
    gsub(/^[ \t]+|[ \t]+$/, "", text)
    
    # Output CSV
    # Format: note_id,sequence_action,"body",part_id
    printf "%s,%s,\"%s\",\n", note_id, comment_seq, text
  } else if (match($0, /<text>(.*)/, m)) {
    # Multiline text start
    in_text = 1
    comment_text = m[1]
  }
  next
}

# API format: continue reading multiline text
in_comments && in_text {
  if (match($0, /^(.*)<\/text>/, m)) {
    # End of multiline text
    comment_text = comment_text " " m[1]
    
    # Decode HTML entities
    gsub(/&lt;/, "<", comment_text)
    gsub(/&gt;/, ">", comment_text)
    gsub(/&quot;/, "\"", comment_text)
    gsub(/&apos;/, "'", comment_text)
    gsub(/&amp;/, "\\&", comment_text)
    
    # Escape quotes for CSV
    gsub(/"/, "\"\"", comment_text)
    
    # Trim whitespace
    gsub(/^[ \t]+|[ \t]+$/, "", comment_text)
    
    # Output CSV
    printf "%s,%s,\"%s\",\n", note_id, comment_seq, comment_text
    
    # Reset state
    in_text = 0
    comment_text = ""
  } else {
    # Continue accumulating text
    comment_text = comment_text " " $0
  }
  next
}

in_comment && !/<comment / {
  # Continue reading comment text
  if (match($0, /^(.*)<\/comment>/, content)) {
    # End of multiline comment
    comment_text = comment_text " " content[1]
    
    # Decode HTML entities
    gsub(/&lt;/, "<", comment_text)
    gsub(/&gt;/, ">", comment_text)
    gsub(/&quot;/, "\"", comment_text)
    gsub(/&apos;/, "'", comment_text)
    gsub(/&amp;/, "\\&", comment_text)  # Must be last
    
    # Escape quotes for CSV
    gsub(/"/, "\"\"", comment_text)
    
    # Trim whitespace
    gsub(/^[ \t]+|[ \t]+$/, "", comment_text)
    
    # Output CSV
    printf "%s,%s,\"%s\",\n", note_id, comment_seq, comment_text
    
    # Reset state
    in_comment = 0
    comment_text = ""
  } else {
    # Continue accumulating text
    comment_text = comment_text " " $0
  }
}


# Version update note: API format support has been added (2025-11-24)
# The script now handles both Planet and API formats with multiline text support
