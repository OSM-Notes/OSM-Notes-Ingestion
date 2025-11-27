# Scripts Directory

Utility scripts for data management, backup generation, and maintenance operations.

## Backup Scripts

### Boundaries Backup

Scripts to export geographic boundaries from the database to GeoJSON backup files:

- **`exportCountriesBackup.sh`** - Exports country boundaries
  - Output: `data/countries.geojson`
  - Usage: `./bin/scripts/exportCountriesBackup.sh`
  - See [data/BOUNDARIES_BACKUP.md](../../data/BOUNDARIES_BACKUP.md) for details

- **`exportMaritimesBackup.sh`** - Exports maritime boundaries (EEZ, Contiguous Zones)
  - Output: `data/maritimes.geojson`
  - Usage: `./bin/scripts/exportMaritimesBackup.sh`
  - See [data/BOUNDARIES_BACKUP.md](../../data/BOUNDARIES_BACKUP.md) for details

These backups are automatically used by `processPlanet base` and `updateCountries` to
avoid downloading boundaries from Overpass API when IDs match.

### Note Location Backup

- **`generateNoteLocationBackup.sh`** - Generates CSV backup of note locations
  - Output: `data/noteLocation.csv.zip`
  - Usage: `./bin/scripts/generateNoteLocationBackup.sh`
  - See [bin/README.md](../README.md) for details

## Validation Scripts

- **`validateNoteLocationBackup.sh`** - Validates note location backup files
- **`compareBackupVsCurrentCountries.sh`** - Compares backup country assignments
  with current database state

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

# Commit updated backups
git add data/*.geojson
git commit -m "Update boundaries backup files"
```

## Requirements

- PostgreSQL database with PostGIS extension
- `ogr2ogr` (GDAL) for GeoJSON export
- `jq` (optional) for JSON validation
- Database connection configured in `etc/properties.sh` or via `DBNAME` environment variable

## Author

Andres Gomez (AngocA)
Version: 2025-01-23

