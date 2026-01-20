# Countries Table Update Strategy

## Overview

The `updateCountries.sh` script uses a **temporary tables strategy** to safely update country
boundaries. This approach ensures data integrity, allows for rollback, and prevents data loss during
updates.

## Current Strategy: Temporary Tables + Swap

### How It Works

The update process follows these steps:

```text
1. Create countries_new (temporary table)
2. Load new data into countries_new
3. Compare geometries (countries vs countries_new)
4. If everything OK:
   - Rename countries -> countries_old (backup)
   - Rename countries_new -> countries
   - Optional: Keep countries_old for a while
5. If it fails:
   - Keep original countries
   - Drop countries_new
```

### Advantages

1. **Safety**: Original table remains until everything is verified
2. **Easy rollback**: If something fails, simply don't perform the swap
3. **Comparison**: Geometries can be compared before replacing
4. **No downtime**: Original table remains available during loading
5. **Automatic backup**: `countries_old` remains as backup

## Implementation Details

### 1. Create Temporary Table

```sql
-- Create temporary table with same structure
CREATE TABLE countries_new (LIKE countries INCLUDING ALL);
```

### 2. Load Data into Temporary Table

Data is loaded into `countries_new` instead of directly into `countries`.

### 3. Compare Geometries

The system automatically compares geometries between the old and new tables:

```sql
-- Compare old vs new geometry
-- Returns: 'increased', 'decreased', 'unchanged', 'new', 'deleted'
```

**Metrics compared:**

- **Area**: `ST_Area(geom)` - Did it increase or decrease?
- **Perimeter**: `ST_Perimeter(geom)` - Edge changes
- **Number of vertices**: `ST_NPoints(geom)` - Complexity
- **Bounding box**: `ST_Envelope(geom)` - Spatial extent
- **Hausdorff distance**: Shape changes

### 4. Perform Swap (Only if everything OK)

```sql
-- 1. Rename current table to backup
ALTER TABLE countries RENAME TO countries_old;

-- 2. Rename new table to main
ALTER TABLE countries_new RENAME TO countries;

-- 3. Recreate indexes and constraints on new table
-- (already included with INCLUDING ALL, but verify)
```

### 5. Cleanup (Optional)

```sql
-- Keep backup for N days, then drop
DROP TABLE IF EXISTS countries_old;
```

## Geometry Comparison

### Comparison Function

```sql
CREATE OR REPLACE FUNCTION compare_country_geometries(
  old_country_id INTEGER,
  new_country_id INTEGER
) RETURNS TABLE (
  country_id INTEGER,
  status TEXT,
  area_change_percent NUMERIC,
  perimeter_change_percent NUMERIC,
  vertices_change INTEGER,
  geometry_changed BOOLEAN
)
```

### Change Thresholds

- **No change**: Difference < 0.01% (rounding errors)
- **Minor change**: 0.01% - 1% (minor adjustments)
- **Significant change**: > 1% (real boundary changes)

## Usage

### Update Mode (Default)

```bash
# Update countries and automatically re-assign affected notes
./bin/process/updateCountries.sh

# The process:
# 1. Creates countries_new
# 2. Loads data into countries_new
# 3. Compares with countries
# 4. Generates change report
# 5. If everything OK: swap
# 6. If it fails: keeps original countries
```

### Base Mode

```bash
# Recreate countries table from scratch
./bin/process/updateCountries.sh --base

# Same process, but starts fresh
```

## Change Report

After comparison, a report is generated showing changes:

```text
Country ID: 12345 (Colombia)
  Status: increased
  Area change: +0.5% (larger)
  Perimeter change: +2.1% (larger)
  Vertices: +150 (more complex)
  Geometry changed: TRUE
```

## Rollback Procedure

If something goes wrong after the swap:

```sql
-- Restore from backup
ALTER TABLE countries RENAME TO countries_failed;
ALTER TABLE countries_old RENAME TO countries;
```

## Required Scripts

### 1. `sql/process/processCountries_25_createCountryTablesNew.sql`

Creates the temporary `countries_new` table.

### 2. `sql/analysis/compare_country_geometries.sql`

Function and queries to compare geometries.

### 3. `sql/process/processCountries_swapTables.sql`

Script to safely perform table swap.

## Considerations

1. **Disk space**: Requires space for two complete tables temporarily
2. **Processing time**: Comparison adds time, but it's valuable for safety
3. **Indexes**: Must be recreated after swap (or use INCLUDING ALL)
4. **Dependencies**: Other tables/views that depend on `countries` must be updated

## Related Documentation

- **[Documentation.md](./Documentation.md)**: System architecture overview
- **[bin/process/updateCountries.sh](../bin/process/updateCountries.sh)**: Update script
  implementation
- **[Country_Assignment_2D_Grid.md](./Country_Assignment_2D_Grid.md)**: Country assignment strategy
- **[Maritime_Boundaries_Verification.md](./Maritime_Boundaries_Verification.md)**: Maritime
  boundaries handling
