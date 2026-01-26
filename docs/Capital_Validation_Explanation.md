---
title: "Capital Validation Explanation"
description: "Capital validation aims to . If Nepal's geometry is mistakenly"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "validation"
  - "api"
audience:
  - "developers"
project: "OSM-Notes-Ingestion"
status: "active"
---


# Capital Validation Explanation

## Purpose

Capital validation aims to **prevent data cross-contamination**. If Nepal's geometry is mistakenly
downloaded when processing Austria, Austria's capital (Vienna) would NOT be inside Nepal's geometry,
which would detect the error.

## How It Works

### 1. Obtaining Capital Coordinates

The system searches for the country's capital in two ways:

**Option A: "label" node of the relation**

```
[out:json];
relation(ID);
node(r:"label");
out center;
```

The "label" node is part of the OSM relation and generally points to the capital or main city of the
country.

**Option B: Node with capital=yes tag (fallback)**

```
[out:json];
relation(ID);
node(r)[capital=yes];
out center;
```

If the label node is not found, it searches for nodes within the relation that have the
`capital=yes` tag.

### 2. Spatial Validation

Once the capital coordinates (lat, lon) are obtained, it is verified that this point is **inside the
downloaded geometry**:

```sql
SELECT ST_Contains(
  ST_Union(geometry),
  ST_SetSRID(ST_MakePoint(lon, lat), 4326)
)
FROM import
WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon');
```

**What does this query do?**

1. **Filters only polygons**: `WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')`
   - Ignores LineString and Point features
   - Only processes geometries with area

2. **Unites all geometries**: `ST_Union(geometry)`
   - If there are multiple polygons (islands, exclaves), unites them into one
   - If there is a single polygon, returns it as is

3. **Verifies containment**: `ST_Contains(unified_geometry, capital_point)`
   - Returns `true` if the point is **strictly inside** the geometry
   - Returns `false` if the point is outside or on the edge

### 3. Result Interpretation

- **✅ `true` (PASS)**: Capital is inside → Geometry corresponds to the correct country
- **❌ `false` (FAIL)**: Capital is outside → Possible cross-contamination → Import is rejected

## Identified Problems

### Problem 1: Invalid Geometries (Self-Intersection)

**Symptom**: Geometry with "Ring Self-intersection"

**Cause**: The geometry downloaded from OSM has intersections in the polygon rings, causing
`ST_IsValid` to return `false`.

**Effect**: Although `ST_Contains` can work with invalid geometries in some cases, there may be
unexpected behaviors.

**Proposed solution**: Use `ST_MakeValid()` before validation:

```sql
SELECT ST_Contains(
  ST_MakeValid(ST_Union(geometry)),
  ST_SetSRID(ST_MakePoint(lon, lat), 4326)
)
```

### Problem 2: ST_Contains is Strict with Edges

**Symptom**: Points very close to the edge may fail

**Cause**: `ST_Contains` requires the point to be **strictly inside**. If the point is exactly on
the edge, it returns `false`.

**Proposed solution**: Use `ST_Intersects` or add tolerance:

```sql
-- Option A: ST_Intersects (more tolerant)
SELECT ST_Intersects(
  ST_MakeValid(ST_Union(geometry)),
  ST_SetSRID(ST_MakePoint(lon, lat), 4326)
)

-- Option B: Tolerance with ST_DWithin
SELECT ST_DWithin(
  ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
  ST_Boundary(ST_MakeValid(ST_Union(geometry)))::geography,
  100  -- 100 meters tolerance
)
```

### Problem 3: ST_Union with Multiple Features

**Symptom**: Countries with many islands or fragmented parts

**Cause**: `ST_Union` of many features can be slow or fail if there are topology problems.

**Solution**: Already filtered by geometry type, but might need `ST_MakeValid` after the union.

## Use Cases

### Case 1: Real Cross-Contamination

**Example**: Nepal's geometry is downloaded for Austria

- Austria's capital: Vienna (48.21°N, 16.37°E)
- Downloaded geometry: Nepal (approx. 26°N-30°N, 80°E-88°E)
- **Result**: `ST_Contains` returns `false` ✅ **Correct detection**

### Case 2: Regional Capital (False Positive)

**Example**: Regional capital is obtained instead of the national one

- Obtained capital: Salzburg (47.59°N, 14.12°E) - regional capital
- Geometry: Complete Austria
- **Expected result**: `ST_Contains` should return `true` because Salzburg is inside Austria
- **Problem**: If it fails, indicates a problem with the geometry, not with the coordinates

### Case 3: Invalid Geometry (Self-Intersection)

**Example**: Austria with self-intersection in the polygon

- Geometry: Invalid (self-intersection)
- Capital: Inside Austria
- **Observed result**: `ST_Contains` may return `true` even with invalid geometry, but the behavior
  is not guaranteed
- **Solution**: Use `ST_MakeValid` to correct the geometry before validating

## Possible Causes of False Negative

### Problem with Error Handling

The code has:

```bash
VALIDATION_RESULT=$(psql ... || echo "false")
```

This means that **if the SQL query fails for ANY reason**, it returns "false". Possible failure
causes:

1. **Empty or non-existent `import` table**: If ogr2ogr failed silently
2. **PostGIS errors with invalid geometries**: Although `ST_Contains` can work, PostGIS may return
   an error in some cases with self-intersection
3. **Concurrency problems**: If multiple processes use the same `import` table
4. **Connection or permission errors**: Temporarily

### Proposed Solution

Improve error handling and add validations:

```bash
# 1. Verify that the table has data
IMPORT_COUNT=$(psql -d "${DB_NAME}" -Atq -c "SELECT COUNT(*) FROM import WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon');" 2> /dev/null || echo "0")

if [[ "${IMPORT_COUNT}" -eq "0" ]]; then
  __loge "No polygon geometries found in import table - cannot validate"
  return 1
fi

# 2. Use ST_MakeValid and better error handling
VALIDATION_RESULT=$(psql -d "${DB_NAME}" -Atq << EOF 2> /dev/null || echo "false"
  SELECT ST_Contains(
    ST_MakeValid(ST_Union(geometry)),
    ST_SetSRID(ST_MakePoint(${CAPITAL_LON}, ${CAPITAL_LAT}), 4326)
  )
  FROM import
  WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')
    AND NOT ST_IsEmpty(geometry);
EOF
)

# 3. Verify the result and log details if it fails
if [[ "${VALIDATION_RESULT}" != "t" ]] && [[ "${VALIDATION_RESULT}" != "true" ]]; then
  # Verify with ST_Intersects as fallback
  INTERSECTS_RESULT=$(psql -d "${DB_NAME}" -Atq -c "
    SELECT ST_Intersects(
      ST_MakeValid(ST_Union(geometry)),
      ST_SetSRID(ST_MakePoint(${CAPITAL_LON}, ${CAPITAL_LAT}), 4326)
    )
    FROM import
    WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon');
  " 2> /dev/null || echo "false")

  __logw "ST_Contains failed, ST_Intersects result: ${INTERSECTS_RESULT}"
fi
```

## Recommendations

1. **Use `ST_MakeValid`** before validating to handle invalid geometries
2. **Add verification that the `import` table has data** before validating
3. **Improve error handling**: Don't assume that any error means "false"
4. **Add detailed logging** when it fails to diagnose better
5. **Consider `ST_Intersects` as fallback** if `ST_Contains` fails
6. **Validate geometries before ST_Union**: Filter invalid geometries or correct them

---

## Related Documentation

- **[ST_DWithin_Explanation.md](./ST_DWithin_Explanation.md)**: Detailed explanation of ST_DWithin
  function used in capital validation
- **[Country_Assignment_2D_Grid.md](./Country_Assignment_2D_Grid.md)**: Country assignment strategy
  and spatial operations
- **[bin/lib/boundaryProcessingFunctions.sh](../bin/lib/boundaryProcessingFunctions.sh)**: Boundary
  processing functions including capital validation
- **[bin/process/updateCountries.sh](../bin/process/updateCountries.sh)**: Country boundary
  processing script
- **[PostgreSQL_Setup.md](./PostgreSQL_Setup.md)**: PostGIS installation and spatial function setup

**Date**: 2025-12-07  
**Version**: 1.0
