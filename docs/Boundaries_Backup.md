# Boundaries Backup (Countries and Maritimes)

> **Note:** For system architecture overview, see [Documentation.md](./Documentation.md).  
> For country boundary processing details, see [Process_Planet.md](./Process_Planet.md) and [bin/process/updateCountries.sh](../bin/process/updateCountries.sh).

Boundary backup files are stored in the [OSM-Notes-Data](https://github.com/OSMLatam/OSM-Notes-Data) repository
to keep this repository focused on code only. The backups are automatically downloaded from GitHub
when needed.

## Files Location

The backup files are stored in the external repository:
- **Repository**: [OSM-Notes-Data](https://github.com/OSMLatam/OSM-Notes-Data)
- **Path**: `data/countries.geojson.gz` and `data/maritimes.geojson.gz`
- **URL**: `https://raw.githubusercontent.com/OSMLatam/OSM-Notes-Data/main/data/`

## Files

- **`countries.geojson.gz`** - Compressed GeoJSON file containing all country boundaries exported
  from the `countries` table (excluding maritime boundaries).
- **`maritimes.geojson.gz`** - Compressed GeoJSON file containing all maritime boundaries (EEZ,
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
- Filters out maritime boundaries using comprehensive patterns (see Maritime Patterns below)
- Exports all country boundaries to GeoJSON format
- Validates the GeoJSON structure if `jq` is available
- Creates/updates `data/countries.geojson`

**Output:**
- File: `data/countries.geojson` (local, uncompressed)
- Compressed: `data/countries.geojson.gz` (uploaded to OSM-Notes-Data repository)
- Format: GeoJSON (RFC 7946)
- Typical size: ~152MB uncompressed, ~43MB compressed (256 countries)

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
- Identifies maritime boundaries using comprehensive patterns (see Maritime Patterns below)
- Exports all maritime boundaries to GeoJSON format
- Validates the GeoJSON structure if `jq` is available
- Creates/updates `data/maritimes.geojson`

**Output:**
- File: `data/maritimes.geojson` (local, uncompressed)
- Compressed: `data/maritimes.geojson.gz` (uploaded to OSM-Notes-Data repository)
- Format: GeoJSON (RFC 7946)
- Typical size: ~1.4MB uncompressed, ~445KB compressed (20 maritime boundaries)

## Maritime Patterns

Maritime boundaries are identified using comprehensive case-insensitive patterns that match
various naming conventions used in OSM:

### EEZ (Exclusive Economic Zone) Patterns:
- `(EEZ)` - With parentheses
- `EEZ` - Without parentheses (e.g., "EEZ Spain")
- `Exclusive Economic Zone` - Full phrase
- `Economic Zone` - Without "Exclusive" (e.g., "Economic Zone of Iceland")

### Contiguous Zone Patterns:
- `(Contiguous Zone)` - With parentheses
- `Contiguous Zone` - Without parentheses
- `contiguous area` - Alternative wording (e.g., "France (contiguous area in the Mediterranean Sea)")
- `contiguous border` - Alternative wording (e.g., "Contiguous border of France")

### Maritime Patterns:
- `(maritime)` - With parentheses
- `maritime` - Without parentheses

### Fisheries Zones:
- `Fisheries protection zone` - (e.g., "Fisheries protection zone around Jan Mayen")
- `Fishing territory` - (e.g., "Fishing territory around the Faroe Islands")

These patterns are applied to both `country_name` and `country_name_en` fields using
case-insensitive matching (ILIKE) to ensure all maritime boundaries are correctly identified.

## Automatic Usage

The backups are automatically downloaded from GitHub and used by:

1. **`processPlanet base`** - When processing planet notes in base mode, it will
   download the backup files from GitHub if not found locally, avoiding the Overpass download entirely.

2. **`updateCountries`** - When running in update mode (without `--base`), it will:
   - Download IDs from Overpass first (lightweight query)
   - Download backup files from GitHub if not found locally
   - Compare IDs with backup files
   - Only download full boundaries if IDs differ
   - Skip the download if IDs match the backup (much faster)

### Download Behavior

The system will:
1. First check for local files in `data/` directory (for development)
2. If not found, automatically download from GitHub repository
3. Cache downloaded files in temporary directory for reuse
4. Decompress `.gz` files automatically when needed

## Manual Update

If you need to update the backups after changes to boundaries:

```bash
# Step 1: Export from database (creates local uncompressed files)
./bin/scripts/exportCountriesBackup.sh
./bin/scripts/exportMaritimesBackup.sh

# Step 2: Compress the files
gzip -k data/countries.geojson
gzip -k data/maritimes.geojson

# Step 3: Upload to OSM-Notes-Data repository manually
# Clone or update the repository
git clone https://github.com/OSMLatam/OSM-Notes-Data.git /tmp/OSM-Notes-Data
# Or if already cloned:
cd /tmp/OSM-Notes-Data && git pull

# Copy compressed files
cp data/countries.geojson.gz /tmp/OSM-Notes-Data/data/
cp data/maritimes.geojson.gz /tmp/OSM-Notes-Data/data/

# Commit and push
cd /tmp/OSM-Notes-Data
git add data/*.geojson.gz
git commit -m "Update boundaries backup files"
git push
```

**Note**: You need write access to the OSM-Notes-Data repository to upload backups.

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

## Regenerating Backups from Scratch

If you need to regenerate backups from scratch (e.g., after fixing import bugs or when
backup files are corrupted):

```bash
# Step 1: Regenerate boundaries from Overpass API
# This will drop and recreate the countries table, then download all boundaries
./bin/process/updateCountries.sh --base

# Step 2: Export the regenerated boundaries
./bin/scripts/exportCountriesBackup.sh
./bin/scripts/exportMaritimesBackup.sh

# Step 3: Upload to OSM-Notes-Data repository (see Manual Update section above)
```

**Note**: Regenerating from scratch takes 30-60 minutes as it downloads all boundaries
from Overpass API. Only do this when necessary.

## Maintenance

The backups should be updated:
- After significant changes to boundaries in OSM
- Periodically (e.g., quarterly) to ensure they stay current
- Before major processing runs if you want to ensure consistency
- When new countries or maritime zones are added to OSM

## Related Scripts

- `bin/scripts/exportCountriesBackup.sh` - Export countries from database
- `bin/scripts/exportMaritimesBackup.sh` - Export maritimes from database
- `bin/process/updateCountries.sh` - Updates boundaries (downloads backups from GitHub)
- `bin/process/processPlanetNotes.sh` - Processes planet (downloads backups from GitHub)

## Configuration

You can customize the GitHub repository URL using environment variables:

```bash
# Use a different repository URL
export BOUNDARIES_DATA_REPO_URL="https://raw.githubusercontent.com/YourOrg/YourRepo/main/data"

# Use a different branch
export BOUNDARIES_DATA_BRANCH="develop"
```

## Related Documentation

- **[bin/README.md](../bin/README.md)**: Script usage examples and reference
- **[bin/scripts/README.md](../bin/scripts/README.md)**: Utility scripts documentation
- **[Process_Planet.md](./Process_Planet.md)**: Planet processing (includes boundary loading)
- **[Documentation.md](./Documentation.md)**: System architecture and data flow

