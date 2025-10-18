# AWK Scripts for OSM Notes Processing

This directory contains AWK scripts for extracting and transforming OSM Planet notes data from XML format to CSV format.

## Overview

These AWK scripts replace the previous XSLT-based approach, providing:

- **3.75x faster processing** (~8 min vs ~30 min for full Planet)
- **200x less memory** (~10 MB vs ~2 GB per process)
- **No external dependencies** (AWK is built-in on Unix systems)
- **Simpler code** (~130 lines vs 1000+ lines of XSLT)

## Files

### `extract_notes.awk`

Extracts note metadata from OSM Planet XML to CSV format.

**Input:** OSM Planet XML file (e.g., `planet-notes.osn`)

**Output Format:**

```csv
note_id,latitude,longitude,created_at,status,closed_at,id_country
```

**Fields:**

- `note_id`: OSM note ID (integer)
- `latitude`: Decimal latitude
- `longitude`: Decimal longitude
- `created_at`: Timestamp when note was created
- `status`: Note status ('open' or 'close')
- `closed_at`: Timestamp when note was closed (empty if open)
- `id_country`: Country ID (empty, filled later by PostgreSQL function)

**Usage:**

```bash
awk -f awk/extract_notes.awk planet-notes.xml > notes.csv
```

---

### `extract_comments.awk`

Extracts comment metadata from OSM Planet XML to CSV format.

**Input:** OSM Planet XML file

**Output Format:**

```csv
note_id,sequence_action,event,created_at,id_user,username
```

**Fields:**

- `note_id`: OSM note ID
- `sequence_action`: Comment sequence number (1, 2, 3...) per note
- `event`: Comment event type ('opened', 'closed', 'reopened', 'commented', 'hidden')
- `created_at`: Timestamp when comment was created
- `id_user`: OSM user ID (empty for anonymous comments)
- `username`: OSM username (empty for anonymous comments)

**Usage:**

```bash
awk -f awk/extract_comments.awk planet-notes.xml > comments.csv
```

---

### `extract_comment_texts.awk`

Extracts comment text content from OSM Planet XML to CSV format.

**Input:** OSM Planet XML file

**Output Format:**

```csv
note_id,sequence_action,"body"
```

**Fields:**

- `note_id`: OSM note ID
- `sequence_action`: Comment sequence number (matches extract_comments.awk)
- `body`: Comment text content (quoted, escaped for CSV)

**Features:**

- Handles multiline text
- Decodes HTML entities (&lt;, &gt;, &amp;, &quot;, &apos;)
- Escapes quotes for CSV compatibility
- Trims whitespace

**Usage:**

```bash
awk -f awk/extract_comment_texts.awk planet-notes.xml > texts.csv
```

---

## Integration

These AWK scripts are used by:
- `bin/functionsProcess.sh` - Calls AWK scripts during Planet processing
- `bin/process/extractPlanetNotesAwk.sh` - Wrapper script for batch extraction

## Performance

Tested on OSM Planet with ~4.87M notes:

| Metric | Value |
|--------|-------|
| Processing time | ~8 minutes |
| Memory usage | ~10 MB per process |
| Throughput | ~10,000 notes/second |
| Parallel processes | 10 (default) |

## Technical Details

### Why AWK over XSLT?

1. **Performance:** AWK is optimized for text processing and runs directly in memory
2. **Simplicity:** Easier to understand and maintain than XSLT templates
3. **Dependencies:** AWK is available on all Unix systems, no external tools needed
4. **Debugging:** Simple print statements vs complex XSLT debugging

### Implementation Notes

- Uses `match()` function for regex pattern extraction
- Handles optional attributes (e.g., `closed_at`, `uid`, `user`)
- Maintains state across lines (e.g., `note_id` for comments)
- Implements counters (e.g., `sequence_action`) per note
- CSV output compatible with PostgreSQL `COPY` command

## See Also

- `docs/AWK_vs_XSLT_Analysis.md` - Technical comparison
- `docs/AWK_Quick_Start.md` - Quick start guide
- `xslt/` - Previous XSLT implementation (deprecated)

## Author

Andres Gomez (AngocA)

## Version

2025-10-18
