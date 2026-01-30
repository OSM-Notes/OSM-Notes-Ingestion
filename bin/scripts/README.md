# Scripts Directory

Utility scripts for data management, backup generation, and maintenance operations.

## Backup Scripts

### Boundaries Backup

Scripts to export geographic boundaries from the database to GeoJSON backup files:

- **`exportCountriesBackup.sh`** - Exports country boundaries
  - Output: `data/countries.geojson`
  - Usage: `./bin/scripts/exportCountriesBackup.sh`
  - See [Boundaries_Backup.md](../../docs/Boundaries_Backup.md) for details

- **`exportMaritimesBackup.sh`** - Exports maritime boundaries (EEZ, Contiguous Zones)
  - Output: `data/maritimes.geojson`
  - Usage: `./bin/scripts/exportMaritimesBackup.sh`
  - See [Boundaries_Backup.md](../../docs/Boundaries_Backup.md) for details

These backups are automatically used by `processPlanet base` and `updateCountries` to avoid
downloading boundaries from Overpass API when IDs match.

### Note Location Backup

- **`generateNoteLocationBackup.sh`** - Generates CSV backup of note locations
  - Purpose: Exports note_id and id_country pairs to CSV for faster subsequent processing
  - Output: `data/noteLocation.csv.zip` (compressed CSV)
  - Usage: `./bin/scripts/generateNoteLocationBackup.sh`
  - Database: Uses `DBNAME` from environment or `etc/properties.sh` (default: `notes`)
  - When to run: After initial Planet load or when country assignments change significantly
  - Performance: Significantly speeds up country assignment by avoiding spatial queries for existing
    notes
  - See [bin/README.md](../README.md) for details

## Usage Examples

### Export Boundaries from Production

```bash
# On production server
cd /home/notes/OSM-Notes-Ingestion
DBNAME=notes ./bin/scripts/exportCountriesBackup.sh
DBNAME=notes ./bin/scripts/exportMaritimesBackup.sh

# Copy to local repository
scp 192.168.0.7:/home/notes/OSM-Notes-Ingestion/data/*.geojson data/
```

### Update Backups After Changes

```bash
# After running updateCountries and verifying changes
./bin/scripts/exportCountriesBackup.sh
./bin/scripts/exportMaritimesBackup.sh

# Compress files for upload
gzip -k data/countries.geojson
gzip -k data/maritimes.geojson

# Upload to OSM-Notes-Data repository (requires write access)
# See docs/Boundaries_Backup.md for detailed upload instructions
```

**Note**: To regenerate backups from scratch (e.g., after fixing import bugs), run:

```bash
# Regenerate boundaries from Overpass
./bin/process/updateCountries.sh --base

# Then export backups
./bin/scripts/exportCountriesBackup.sh
./bin/scripts/exportMaritimesBackup.sh
```

## Detailed Script Documentation

### `exportCountriesBackup.sh`

**Purpose**: Exports country boundaries from database to GeoJSON format.

**Functionality**:

- Queries `countries` table from database
- Exports to GeoJSON using `ogr2ogr` (GDAL)
- Validates output with `jq` (if available)
- Creates `data/countries.geojson`

**Usage**:

```bash
# Basic usage
./bin/scripts/exportCountriesBackup.sh

# With specific database
DBNAME=osm_notes ./bin/scripts/exportCountriesBackup.sh
```

**When to Run**:

- After `updateCountries.sh --base` completes successfully
- After manual boundary corrections
- Before major system updates (backup)
- Monthly maintenance (recommended)

**Output Format**: GeoJSON with country geometries and metadata

### `exportMaritimesBackup.sh`

**Purpose**: Exports maritime boundaries (EEZ, Contiguous Zones) from database to GeoJSON.

**Functionality**:

- Queries `maritimes` table from database
- Exports to GeoJSON using `ogr2ogr`
- Creates `data/maritimes.geojson`

**Usage**: Same as `exportCountriesBackup.sh`

**When to Run**: Same as country backups

### `generateNoteLocationBackup.sh`

**Purpose**: Generates compressed CSV backup of note locations (note_id, id_country pairs).

**Functionality**:

- Exports all notes with country assignments from `notes` table
- Creates CSV file: `note_id,id_country`
- Compresses to ZIP format
- Output: `data/noteLocation.csv.zip`

**Usage**:

```bash
# Basic usage
./bin/scripts/generateNoteLocationBackup.sh

# With specific database
DBNAME=osm_notes ./bin/scripts/generateNoteLocationBackup.sh
```

**When to Run**:

- After initial Planet load completes
- After country assignment process completes
- Before major data migrations
- Monthly maintenance (recommended)

**Performance Impact**:

- File size: ~50-100 MB compressed (depends on note count)
- Generation time: 5-15 minutes for full dataset
- Speeds up subsequent country assignment by 10-100x

**How It's Used**:

- Automatically loaded by `processPlanetNotes.sh` and `noteProcessingFunctions.sh`
- Allows skipping spatial queries for notes that already have country assignments
- See `sql/functionsProcess_31_loadsBackupNoteLocation.sql` for loading logic

## Requirements

- **PostgreSQL database** with PostGIS extension
- **ogr2ogr** (GDAL) for GeoJSON export
- **jq** (optional) for JSON validation
- **Database connection** configured in `etc/properties.sh` or via `DBNAME` environment variable
- **Read/write access** to `data/` directory for backup files

## Common Workflows

### Initial Setup Workflow

```bash
# 1. Load initial data
./bin/process/processPlanetNotes.sh --base
./bin/process/updateCountries.sh --base

# 2. Generate backups
./bin/scripts/generateNoteLocationBackup.sh
./bin/scripts/exportCountriesBackup.sh
./bin/scripts/exportMaritimesBackup.sh
```

### Monthly Maintenance Workflow

```bash
# 1. Update boundaries
./bin/process/updateCountries.sh

# 2. Regenerate backups if boundaries changed
./bin/scripts/exportCountriesBackup.sh
./bin/scripts/exportMaritimesBackup.sh

# 3. Regenerate note location backup if needed
./bin/scripts/generateNoteLocationBackup.sh
```

### Troubleshooting Workflow

```bash
# Check logs for issues
# Review updateCountries logs in /tmp/updateCountries_*/
```

## Related Documentation

- **[docs/Boundaries_Backup.md](../../docs/Boundaries_Backup.md)**: Detailed backup documentation
- **[bin/README.md](../README.md)**: Overview of bin directory
- **[bin/lib/README.md](../lib/README.md)**: Function libraries documentation
- **[docs/Documentation.md](../../docs/Documentation.md)**: Complete system documentation
