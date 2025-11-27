# Boundaries Backup (Countries and Maritimes)

This directory contains backups of country and maritime boundaries exported from
the database. These backups are used to avoid downloading boundaries from
Overpass API on every run of `processPlanet base`, significantly speeding up
the process.

## Files

- **`countries.geojson`** - GeoJSON file containing all country boundaries exported
  from the `countries` table (excluding maritime boundaries).
- **`maritimes.geojson`** - GeoJSON file containing all maritime boundaries (EEZ,
  Contiguous Zones, etc.) exported from the `countries` table.

## Export Scripts

Two scripts are provided to export boundaries from the database:

### `bin/scripts/exportCountriesBackup.sh`

Exports country boundaries (excluding maritimes) to `data/countries.geojson`.

**Usage:**
```bash
# Export from default database (notes)
./bin/scripts/exportCountriesBackup.sh

# Export from specific database
DBNAME=osm-notes ./bin/scripts/exportCountriesBackup.sh
```

**What it does:**
- Connects to the database and verifies countries table exists
- Filters out maritime boundaries (identified by patterns like "(EEZ)")
- Exports all country boundaries to GeoJSON format
- Validates the GeoJSON structure if `jq` is available
- Creates/updates `data/countries.geojson`

**Output:**
- File: `data/countries.geojson`
- Format: GeoJSON (RFC 7946)
- Typical size: ~137MB (286 countries)

### `bin/scripts/exportMaritimesBackup.sh`

Exports maritime boundaries to `data/maritimes.geojson`.

**Usage:**
```bash
# Export from default database (notes)
./bin/scripts/exportMaritimesBackup.sh

# Export from specific database
DBNAME=osm-notes ./bin/scripts/exportMaritimesBackup.sh
```

**What it does:**
- Connects to the database and verifies countries table exists
- Identifies maritime boundaries by patterns in names:
  - "(EEZ)" - Exclusive Economic Zone
  - "(Contiguous Zone)" - Contiguous Zone
  - "(maritime)" - Other maritime boundaries
- Exports all maritime boundaries to GeoJSON format
- Validates the GeoJSON structure if `jq` is available
- Creates/updates `data/maritimes.geojson`

**Output:**
- File: `data/maritimes.geojson`
- Format: GeoJSON (RFC 7946)
- Typical size: ~4.9MB (30 maritime boundaries)

## Automatic Usage

The backups are automatically used by:

1. **`processPlanet base`** - When processing planet notes in base mode, it will
   use the backup files if available, avoiding the Overpass download entirely.

2. **`updateCountries`** - When running in update mode (without `--base`), it will:
   - Download IDs from Overpass first (lightweight query)
   - Compare IDs with backup files
   - Only download full boundaries if IDs differ
   - Skip the download if IDs match the backup (much faster)

## Manual Update

If you need to update the backups after changes to boundaries:

```bash
# After running updateCountries and verifying changes
./bin/scripts/exportCountriesBackup.sh
./bin/scripts/exportMaritimesBackup.sh
```

Then commit the updated GeoJSON files to the repository.

## Benefits

- **Faster execution**: Avoids downloading ~2.5GB of data from Overpass API
- **Smart comparison**: Compares IDs first (lightweight) before downloading full data
- **Reduced API load**: Less stress on Overpass servers
- **Reliability**: Works even if Overpass API is temporarily unavailable
- **Version control**: Backups are tracked in git, allowing comparison of changes

## File Format

The backup files are standard GeoJSON files (RFC 7946) with the following structure:

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": 12345,
        "country_name": "Country Name",
        "country_name_es": "Nombre del País",
        "country_name_en": "Country Name"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [...]
      }
    }
  ]
}
```

## Maintenance

The backups should be updated:
- After significant changes to boundaries in OSM
- Periodically (e.g., quarterly) to ensure they stay current
- Before major processing runs if you want to ensure consistency
- When new countries or maritime zones are added to OSM

## Related Scripts

- `bin/scripts/exportCountriesBackup.sh` - Export countries
- `bin/scripts/exportMaritimesBackup.sh` - Export maritimes
- `bin/process/updateCountries.sh` - Updates boundaries (uses backups)
- `bin/process/processPlanetNotes.sh` - Processes planet (uses backups)

## Author

Andres Gomez (AngocA)
Version: 2025-01-23

