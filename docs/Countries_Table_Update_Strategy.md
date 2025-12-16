# Countries Table Update Strategy

**Version:** 2025-12-16  
**Author:** Andres Gomez (AngocA)

## Current Problem Analysis

### Why was the table dropped? (BEFORE - No longer applies)

**NOTE: This strategy is NO LONGER used. The temporary tables strategy has been implemented.**

Previously, `updateCountries.sh` dropped the `countries` table in these cases:

1. **`--base` mode**: Dropped and recreated from scratch
   ```bash
   __dropCountryTables  # DROP TABLE countries CASCADE;
   __createCountryTables
   ```

2. **Update mode**: Did NOT drop, but marked all as `updated=TRUE` and updated them one by one
   ```sql
   UPDATE countries SET updated = TRUE, last_update_attempt = CURRENT_TIMESTAMP
   ```

### New Strategy Implemented (2025-12-16)

Now `updateCountries.sh` uses a temporary tables strategy:

1. **`--base` mode**: Creates `countries_new`, loads data, compares, and performs swap
2. **Update mode**: Creates `countries_new`, loads data, compares geometries, and swaps only if safe

### Problems with the Previous Strategy

1. **Data loss risk**: If the process fails during loading, the table may remain empty or corrupted
2. **No rollback**: No way to revert to the previous version if something goes wrong
3. **No comparison**: New geometry is not compared with the old one before replacing
4. **Downtime**: During update, the table may be in an inconsistent state

## Proposed Strategy: Temporary Tables + Swap

### Concept

Similar to how API tables (`notes_api`, `note_comments_api`) are handled, use a temporary table to load new data, compare with existing data, and only perform the swap if everything is correct.

### Proposed Flow

```
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

## Implementation

### 1. Create Temporary Table

```sql
-- Create temporary table with same structure
CREATE TABLE countries_new (LIKE countries INCLUDING ALL);
```

### 2. Load Data into Temporary Table

The loading process is the same, but into `countries_new` instead of `countries`.

### 3. Compare Geometries

Function to compare geometries and detect changes:

```sql
-- Compare old vs new geometry
-- Returns: 'increased', 'decreased', 'unchanged', 'new', 'deleted'
```

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

### Metrics to Compare

1. **Area**: `ST_Area(geom)` - Did it increase or decrease?
2. **Perimeter**: `ST_Perimeter(geom)` - Edge changes
3. **Number of vertices**: `ST_NPoints(geom)` - Complexity
4. **Bounding box**: `ST_Envelope(geom)` - Spatial extent
5. **Hausdorff distance**: Shape changes

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

## Implementation Status

### ✅ Phase 1: Preparation - COMPLETED

1. ✅ Geometry comparison function created (`compare_country_geometries.sql`)
2. ✅ SQL script to create temporary table implemented
3. ✅ `__createCountryTablesNew` function created

### ✅ Phase 2: Load into Temporary Table - COMPLETED

1. ✅ `__processCountries` modified to use `countries_new` when `USE_COUNTRIES_NEW=true`
2. ✅ `boundaryProcessingFunctions.sh` modified to insert into dynamic table
3. ✅ Update logic maintained

### ✅ Phase 3: Comparison and Validation - COMPLETED

1. ✅ `__compareCountryGeometries` function implemented
2. ✅ Automatically generates change report
3. ✅ Validates if swap is safe before proceeding

### ✅ Phase 4: Conditional Swap - COMPLETED

1. ✅ `__swapCountryTables` function implemented
2. ✅ Only swaps if validation passes (or if forced with `FORCE_SWAP_ON_WARNING=true`)
3. ✅ Maintains automatic backup (`countries_old`)
4. ✅ Cleans up temporary table after swap

## Required Scripts

### 1. `sql/process/processCountries_25_createCountryTablesNew.sql`

Creates the temporary `countries_new` table.

### 2. `sql/analysis/compare_country_geometries.sql`

Function and queries to compare geometries.

### 3. `sql/process/processCountries_swapTables.sql`

Script to safely perform table swap.

## Usage Example

```bash
# Update mode with new strategy
./bin/process/updateCountries.sh

# The process:
# 1. Creates countries_new
# 2. Loads data into countries_new
# 3. Compares with countries
# 4. Generates change report
# 5. If everything OK: swap
# 6. If it fails: keeps original countries
```

## Change Report

After comparison, a report is generated:

```
Country ID: 12345 (Colombia)
  Status: increased
  Area change: +0.5% (larger)
  Perimeter change: +2.1% (larger)
  Vertices: +150 (more complex)
  Geometry changed: TRUE
```

## Rollback

If something goes wrong after the swap:

```sql
-- Restore from backup
ALTER TABLE countries RENAME TO countries_failed;
ALTER TABLE countries_old RENAME TO countries;
```

## Considerations

1. **Disk space**: Requires space for two complete tables temporarily
2. **Processing time**: Comparison adds time, but it's valuable
3. **Indexes**: Must be recreated after swap (or use INCLUDING ALL)
4. **Dependencies**: Other tables/views that depend on `countries` must be updated

## Next Steps

1. ✅ Implement comparison function
2. ✅ Modify `updateCountries.sh` to use temporary table
3. ✅ Add validations before swap
4. Test in development environment
5. ✅ Document complete process
