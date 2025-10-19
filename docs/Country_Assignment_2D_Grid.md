# Country Assignment with Intelligent 2D Grid Partitioning

## Overview

This document describes the intelligent 2D grid partitioning strategy used to
assign countries to OpenStreetMap notes efficiently.

The strategy minimizes expensive `ST_Contains` PostGIS operations by dividing
the world into **24 geographic zones** based on both **longitude and latitude**,
and maintaining priority-ordered country lists for each zone.

## Motivation

### The Problem

Previously, the world was divided into only **5 vertical zones** based solely
on longitude:

- Americas (lon < -30)
- Europe/Africa (lon < 25)
- Russia/Middle East (lon < 65)
- Asia/Oceania (lon >= 65)
- Null Island (special case)

This approach had limitations:

1. **Too broad**: Each zone contained too many countries
2. **No latitude consideration**: Zones spanned from pole to pole
3. **Inefficient**: More `ST_Contains` calls needed to find the right country
4. **Uneven distribution**: Some zones had many more notes than others

### Why ST_Contains is Expensive

`ST_Contains(geometry, point)` is computationally expensive because:

- **Complex polygons**: Country boundaries have thousands of vertices
- **Ray-casting algorithm**: Requires multiple geometric calculations
- **No early exit**: Must complete the full calculation for each country
- **Cumulative cost**: Called repeatedly until a match is found

**Example**: In the old system, finding a note in Germany required checking:
1. Is it in France? (ST_Contains call #1)
2. Is it in Germany? (ST_Contains call #2) ✓ Found!

With the new system, Germany is #1 in the Western Europe zone, so only **one
ST_Contains call** is needed.

## The Solution: 2D Grid Partitioning

### Key Principles

1. **Geographic logic**: Zones align with natural regions and continents
2. **Density-based**: High-density areas (Western Europe, USA) get dedicated
   zones
3. **Priority ordering**: Within each zone, countries are ordered by note
   density
4. **Minimize cross-zone**: Country assignments minimize border overlaps

### The 24 Geographic Zones

The world is divided into 24 zones, each with specific lon/lat boundaries:

#### Americas (6 zones)

| Zone | Region | Lon Range | Lat Range | Key Countries |
|------|--------|-----------|-----------|---------------|
| 1 | USA/Canada | -150 to -60 | 30 to 75 | USA, Canada |
| 2 | Mexico/Central America | -120 to -75 | 5 to 35 | Mexico, Guatemala, Nicaragua |
| 3 | Caribbean | -90 to -60 | 10 to 30 | Cuba, Haiti, Dominican Republic |
| 4 | Northern South America | -80 to -35 | -15 to 15 | Brazil, Colombia, Ecuador, Venezuela |
| 5 | Southern South America | -75 to -35 | -56 to -15 | Argentina, Chile, Uruguay |
| 6 | Pacific Islands | 130 to -120* | -30 to 30 | Fiji, French Polynesia, Samoa |

*Wraps around International Date Line

#### Europe (4 zones)

| Zone | Region | Lon Range | Lat Range | Key Countries |
|------|--------|-----------|-----------|---------------|
| 7 | Western Europe | -10 to 15 | 35 to 60 | Germany, France, UK, Spain |
| 8 | Eastern Europe | 15 to 45 | 35 to 60 | Poland, Czechia, Ukraine |
| 9 | Northern Europe | -10 to 35 | 55 to 75 | Scandinavia, Baltic states |
| 10 | Southern Europe | -10 to 30 | 30 to 50 | Italy, Greece, Balkans |

#### Africa (4 zones)

| Zone | Region | Lon Range | Lat Range | Key Countries |
|------|--------|-----------|-----------|---------------|
| 11 | Northern Africa | -20 to 50 | 15 to 40 | Morocco, Algeria, Egypt |
| 12 | Western Africa | -20 to 20 | -10 to 20 | Nigeria, Ghana, DRC |
| 13 | Eastern Africa | 20 to 55 | -15 to 20 | Kenya, Ethiopia, Tanzania |
| 14 | Southern Africa | 10 to 50 | -36 to -15 | South Africa, Namibia |

#### Asia (6 zones)

| Zone | Region | Lon Range | Lat Range | Key Countries |
|------|--------|-----------|-----------|---------------|
| 15 | Middle East | 25 to 65 | 10 to 45 | Turkey, Iran, Saudi Arabia |
| 16 | Russia North | 25 to 180 | 55 to 80 | Northern Russia, Siberia |
| 17 | Russia South | 30 to 150 | 40 to 60 | Southern Russia, Kazakhstan |
| 18 | Central Asia | 45 to 90 | 30 to 55 | Uzbekistan, Kyrgyzstan |
| 19 | India/South Asia | 60 to 95 | 5 to 40 | India, Pakistan, Bangladesh |
| 20 | Southeast Asia | 95 to 140 | -12 to 25 | Thailand, Vietnam, Indonesia |
| 21 | Eastern Asia | 100 to 145 | 20 to 55 | China, Japan, Korea |

#### Oceania (1 zone)

| Zone | Region | Lon Range | Lat Range | Key Countries |
|------|--------|-----------|-----------|---------------|
| 22 | Australia/NZ | 110 to 180 | -50 to -10 | Australia, New Zealand |

#### Polar Regions (2 zones)

| Zone | Region | Lon Range | Lat Range | Coverage |
|------|--------|-----------|-----------|----------|
| 23 | Arctic | all | > 70 | Greenland, Svalbard, northern territories |
| 24 | Antarctic | all | < -60 | Antarctica, sub-Antarctic islands |

#### Special Zone

| Zone | Region | Lon Range | Lat Range | Notes |
|------|--------|-----------|-----------|-------|
| 0 | Null Island | -4 to 4 | -5 to 4.53 | Gulf of Guinea, test location |

## How It Works

### The Algorithm

```sql
FUNCTION get_country(lon, lat, note_id):
  
  -- Step 1: Check if note is still in current country (95% hit rate!)
  IF note already has country assigned THEN
    IF ST_Contains(current_country.geom, point) THEN
      RETURN current_country  -- Fast path!
    END IF
  END IF
  
  -- Step 2: Determine geographic zone using lon AND lat
  zone = determine_zone(lon, lat)  -- Simple range checks
  
  -- Step 3: Search countries in priority order for that zone
  FOR country IN countries_ordered_by_zone_priority(zone):
    IF ST_Contains(country.geom, point) THEN
      RETURN country
    END IF
  END FOR
  
  RETURN -1  -- Not found
```

### Performance Optimization

The function has three levels of optimization:

1. **Same country check (95% hit rate)**
   - When updating boundaries, 95% of notes stay in the same country
   - One `ST_Contains` call, immediate return

2. **2D zone selection (O(1) operation)**
   - Simple range comparisons on lon/lat
   - Reduces candidate countries from ~250 to ~10-30

3. **Priority-ordered search**
   - Within zone, check high-density countries first
   - Average case: 1-3 `ST_Contains` calls
   - Worst case: ~10-20 calls (vs. ~100+ in old system)

### Example: Note in Berlin, Germany

```
Coordinates: (52.52, 13.40)

Step 1: Check current country
  - If previously assigned to Germany → ST_Contains → YES → DONE! (1 call)
  
Step 2: Determine zone
  - lon = 13.40, lat = 52.52
  - Matches: Western Europe zone (lon: -10 to 15, lat: 35 to 60)
  
Step 3: Search in priority order for Western Europe
  - Priority 1: Germany → ST_Contains → YES → DONE! (1 call)
  
Total: 1-2 ST_Contains calls
Old system: Could take 5-10 calls searching through all Europe
```

### Example: Note in Tokyo, Japan

```
Coordinates: (35.68, 139.69)

Step 1: Check current country
  - Not assigned yet
  
Step 2: Determine zone
  - lon = 139.69, lat = 35.68
  - Matches: Eastern Asia zone (lon: 100 to 145, lat: 20 to 55)
  
Step 3: Search in priority order for Eastern Asia
  - Priority 1: China → ST_Contains → NO
  - Priority 1: Japan → ST_Contains → YES → DONE! (2 calls)
  
Total: 2 ST_Contains calls
Old system: Could take 10-20 calls through all Asia/Oceania
```

## Database Schema

### Table: countries

New columns added for 2D grid:

```sql
CREATE TABLE countries (
  -- Existing columns
  country_id INTEGER NOT NULL,
  country_name VARCHAR(100) NOT NULL,
  country_name_es VARCHAR(100),
  country_name_en VARCHAR(100),
  geom GEOMETRY NOT NULL,
  
  -- Legacy columns (kept for backward compatibility)
  americas INTEGER,
  europe INTEGER,
  russia_middle_east INTEGER,
  asia_oceania INTEGER,
  
  -- New 2D grid zone priority columns
  zone_us_canada INTEGER,
  zone_mexico_central_america INTEGER,
  zone_caribbean INTEGER,
  zone_northern_south_america INTEGER,
  zone_southern_south_america INTEGER,
  zone_western_europe INTEGER,
  zone_eastern_europe INTEGER,
  zone_northern_europe INTEGER,
  zone_southern_europe INTEGER,
  zone_northern_africa INTEGER,
  zone_western_africa INTEGER,
  zone_eastern_africa INTEGER,
  zone_southern_africa INTEGER,
  zone_middle_east INTEGER,
  zone_russia_north INTEGER,
  zone_russia_south INTEGER,
  zone_central_asia INTEGER,
  zone_india_south_asia INTEGER,
  zone_southeast_asia INTEGER,
  zone_eastern_asia INTEGER,
  zone_australia_nz INTEGER,
  zone_pacific_islands INTEGER,
  zone_arctic INTEGER,
  zone_antarctic INTEGER,
  
  updated BOOLEAN
);
```

### Priority Values

For each zone column:
- `1-2`: Very high density (>50K notes)
- `3-5`: High density (10K-50K notes)
- `6-8`: Medium density (1K-10K notes)
- `9-10`: Low density (<1K notes), maritime zones
- `NULL`: Country not in this zone

## Implementation Files

### SQL Files

1. **`sql/process/processPlanetNotes_25_createCountryTables.sql`**
   - Creates `countries` table with all zone columns
   - Creates spatial indexes

2. **`sql/functionsProcess_21_createFunctionToGetCountry.sql`**
   - Contains the `get_country()` function
   - Implements 2D zone detection and priority search

3. **`sql/functionsProcess_31_organizeAreas_2DGrid.sql`**
   - Assigns priority values for all 24 zones
   - Based on note density statistics
   - Run after loading country geometries

### Bash Scripts

1. **`bin/process/updateCountries.sh`**
   - Updates country boundaries from Overpass
   - Re-assigns affected notes efficiently

2. **`bin/process/assignCountriesToNotes.sh`**
   - Assigns countries to all notes
   - Uses parallel processing for performance

## Usage

### Initial Setup

```bash
# 1. Create database tables
psql -d notes -f sql/process/processPlanetNotes_25_createCountryTables.sql

# 2. Load country geometries from Overpass
DBNAME=notes ./bin/process/updateCountries.sh --base

# 3. Assign zone priorities
psql -d notes -f sql/functionsProcess_31_organizeAreas_2DGrid.sql

# 4. Create get_country function
psql -d notes -f sql/functionsProcess_21_createFunctionToGetCountry.sql

# 5. Assign countries to all notes
DBNAME=notes ./bin/process/assignCountriesToNotes.sh
```

### Updating Boundaries

```bash
# Update countries and automatically re-assign affected notes
DBNAME=notes ./bin/process/updateCountries.sh
```

This efficiently re-assigns only notes affected by boundary changes.

### Manual Country Assignment

```sql
-- Assign country to a single note
SELECT get_country(longitude, latitude, note_id) 
FROM notes 
WHERE note_id = 12345;

-- Assign countries to all unassigned notes
UPDATE notes
SET id_country = get_country(longitude, latitude, note_id)
WHERE id_country IS NULL;

-- Re-assign countries to all notes in a specific area
UPDATE notes
SET id_country = get_country(longitude, latitude, note_id)
WHERE longitude BETWEEN 10 AND 20
  AND latitude BETWEEN 40 AND 50;
```

## Performance Metrics

### Expected Improvements

Compared to the old 5-zone vertical partitioning:

| Metric | Old System | New System | Improvement |
|--------|-----------|------------|-------------|
| Average zones checked | N/A | 1 (exact) | - |
| Avg countries per zone | ~50-100 | ~10-30 | **3-10x fewer** |
| Avg ST_Contains calls | 10-30 | 2-5 | **5-10x fewer** |
| Same-country cache hit | 95% | 95% | Same |
| New note assignment | Slow | **Fast** | **5-10x faster** |

### Monitoring Performance

Use the `tries` table to analyze performance:

```sql
-- Average iterations per zone
SELECT area, AVG(iter) as avg_iterations, COUNT(*) as notes
FROM tries
GROUP BY area
ORDER BY notes DESC;

-- Zones with high iteration counts (need optimization)
SELECT area, MAX(iter) as max_iterations, AVG(iter) as avg_iterations
FROM tries
GROUP BY area
HAVING AVG(iter) > 5
ORDER BY avg_iterations DESC;

-- Most efficient zones
SELECT area, AVG(iter) as avg_iterations, COUNT(*) as notes
FROM tries
WHERE area != 'Same country'
GROUP BY area
HAVING COUNT(*) > 100
ORDER BY avg_iterations ASC
LIMIT 10;
```

## Zone Overlap Strategy

Some countries span multiple zones. Strategy:

1. **Primary zone**: Country appears with highest priority
2. **Secondary zones**: Country appears with lower priority
3. **Example**: Russia appears in:
   - `zone_russia_north` (priority 1)
   - `zone_russia_south` (priority 1)
   - `zone_eastern_europe` (priority 8 - border areas)
   - `zone_central_asia` (priority 8 - border areas)

This ensures every note finds its country, even near zone boundaries.

## Migration from Old System

The new system is **backward compatible**:

1. Legacy columns (`americas`, `europe`, etc.) are maintained
2. Fallback logic in `get_country()` uses legacy zones if needed
3. Can run both systems in parallel during migration
4. Gradual rollout possible

### Migration Steps

```bash
# 1. Add new columns to existing countries table
ALTER TABLE countries ADD COLUMN zone_us_canada INTEGER;
ALTER TABLE countries ADD COLUMN zone_western_europe INTEGER;
# ... (add all 24 zone columns)

# 2. Populate zone priorities
psql -d notes -f sql/functionsProcess_31_organizeAreas_2DGrid.sql

# 3. Update get_country function
psql -d notes -f sql/functionsProcess_21_createFunctionToGetCountry.sql

# 4. Test with sample notes
SELECT area, COUNT(*) 
FROM tries 
WHERE created_at > NOW() - INTERVAL '1 day'
GROUP BY area;

# 5. Re-assign all notes (optional, can be done gradually)
# DBNAME=notes ./bin/process/assignCountriesToNotes.sh
```

## Troubleshooting

### High Iteration Counts

If a zone shows high average iterations:

```sql
-- Find which countries are checked most
SELECT area, iter, id_country, COUNT(*) as occurrences
FROM tries
WHERE area = 'Western Europe'
GROUP BY area, iter, id_country
ORDER BY iter DESC, occurrences DESC;
```

**Solution**: Adjust priority order for that zone in
`functionsProcess_31_organizeAreas_2DGrid.sql`

### Notes Not Assigned

If notes remain unassigned:

```sql
-- Find unassigned notes
SELECT note_id, longitude, latitude
FROM notes
WHERE id_country IS NULL OR id_country = -1
LIMIT 100;

-- Check which zone they fall into
SELECT get_country(longitude, latitude, note_id)
FROM notes
WHERE note_id = <problem_note_id>;

-- Check tries table for details
SELECT * FROM tries WHERE id_note = <problem_note_id>;
```

**Common causes**:
1. Note in ocean (expected)
2. Note in disputed territory
3. Zone boundary issue (adjust boundaries)
4. Missing country geometry

### Performance Degradation

If performance degrades:

```sql
-- Rebuild spatial index
REINDEX INDEX countries_spatial;

-- Analyze table
ANALYZE countries;

-- Check index usage
EXPLAIN ANALYZE 
SELECT get_country(-0.1276, 51.5074, 12345);
```

## Future Enhancements

Potential improvements:

1. **Dynamic zone adjustment**: Automatically adjust zone boundaries based on
   note distribution
2. **Machine learning**: Predict country based on nearby notes
3. **Spatial clustering**: Pre-assign countries based on geographic clusters
4. **Caching**: Cache recent country lookups in memory
5. **Parallel execution**: Use PostgreSQL parallel query for bulk assignments

## References

- **PostGIS Documentation**: 
  <https://postgis.net/docs/ST_Contains.html>
- **OpenStreetMap Boundaries**: 
  <https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dadministrative>
- **Spatial Indexing**: 
  <https://postgis.net/docs/using_postgis_dbmanagement.html#spatial_index_intro>

## Author

- **Andres Gomez (AngocA)**
- OSM-LatAm, OSM-Colombia, MaptimeBogota
- Version: 2025-10-19


