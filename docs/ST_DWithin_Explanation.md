---
title: "Explanation: ST_DWithin with Tolerance"
description: "Capital validation within country geometry"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "documentation"
audience:
  - "developers"
project: "OSM-Notes-Ingestion"
status: "active"
---


# Explanation: ST_DWithin with Tolerance

**Date:** 2025-12-08  
**Context:** Capital validation within country geometry

## What is ST_DWithin?

`ST_DWithin` is a PostGIS function that checks if two geometries are **within a specified distance**
of each other.

### Syntax

```sql
ST_DWithin(geometry A, geometry B, distance)
```

**Returns:** `true` if the geometries are within the specified distance, `false` otherwise.

## PostGIS Function Comparison

### 1. ST_Contains

```sql
ST_Contains(geometry, point)
```

**Behavior:**

- Returns `true` ONLY if the point is **strictly inside** the geometry
- If the point is **on the edge**, returns `false`
- This is the strictest function

**Example:**

```
Point inside country: ✅ true
Point on edge: ❌ false
Point outside country: ❌ false
```

### 2. ST_Intersects

```sql
ST_Intersects(geometry, point)
```

**Behavior:**

- Returns `true` if the point is **inside OR on the edge** of the geometry
- More tolerant than `ST_Contains`
- Accepts points on the edge

**Example:**

```
Point inside country: ✅ true
Point on edge: ✅ true (more tolerant)
Point outside country: ❌ false
```

### 3. ST_DWithin (with tolerance)

```sql
ST_DWithin(geometry, point, distance_in_meters)
```

**Behavior:**

- Returns `true` if the point is **inside, on the edge, OR near** the geometry
- Distance is specified in SRID units
- For geographic coordinates (SRID 4326), must use `geography` or transform

**Example with 100 meters tolerance:**

```
Point inside country: ✅ true
Point on edge: ✅ true
Point 50m outside edge: ✅ true (within tolerance)
Point 150m outside edge: ❌ false (outside tolerance)
```

## When to Use Each One?

### ST_Contains (Current - Strict)

✅ **Use when:**

- You need strict validation
- The point MUST be completely inside
- You don't accept points on the edge

❌ **Problem:**

- Fails with points very close to the edge
- Fails with geometries with topology issues

### ST_Intersects (Fallback Implemented - Moderate)

✅ **Use when:**

- You accept points on the edge
- You want more tolerant validation
- Geometries may have minor issues

✅ **Already implemented as fallback:**

- If `ST_Contains` fails, tries with `ST_Intersects`

### ST_DWithin (Optional - Very Tolerant)

✅ **Use when:**

- There is uncertainty in capital coordinates
- Geometries have minor precision errors
- You want to tolerate small differences due to rounding

❌ **Disadvantages:**

- May accept points that are technically outside
- Requires specifying distance (how much tolerance is reasonable?)
- More complex to implement correctly

## ST_DWithin Implementation

### Option 1: Using Geography (Recommended)

```sql
SELECT ST_DWithin(
  ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
  ST_Transform(ST_MakeValid(ST_Union(geometry)), 4326)::geography,
  100  -- 100 meters tolerance
)
FROM import
WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon');
```

**Advantages:**

- Distance in meters (more intuitive)
- Works correctly with geographic coordinates

**Disadvantages:**

- Requires casting to `geography`
- Slightly slower

### Option 2: Using Transformed Geometry

```sql
SELECT ST_DWithin(
  ST_Transform(ST_SetSRID(ST_MakePoint(lon, lat), 4326), 3857),
  ST_Transform(ST_MakeValid(ST_Union(geometry)), 3857),
  100  -- 100 meters in Web Mercator projection
)
FROM import
WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon');
```

**Advantages:**

- Uses metric projection (more precise)
- Doesn't require casting to geography

**Disadvantages:**

- Requires transforming both geometries
- More complex

## Is It Necessary to Implement ST_DWithin?

### Arguments IN FAVOR:

1. **Tolerance to precision errors:**
   - Capital coordinates may have small variations
   - Geometries may have minor rounding errors

2. **Problematic geometries:**
   - Some geometries may have minor precision issues
   - ST_DWithin can help in edge cases

3. **Additional robustness:**
   - One more layer of validation doesn't hurt

### Arguments AGAINST:

1. **ST_Intersects is already tolerant:**
   - Already accepts points on the edge
   - Most cases should be covered with this

2. **May hide real problems:**
   - If the capital is outside the country, ST_DWithin might accept it
   - Could mask real cross-contamination

3. **Additional complexity:**
   - Requires deciding what distance is reasonable (100m? 1km?)
   - More code to maintain

4. **We already have ST_MakeValid:**
   - Fixes most topology problems
   - ST_Intersects handles edge cases

## Recommendation

**It is NOT necessary to implement ST_DWithin now** because:

1. ✅ `ST_MakeValid` fixes topology problems
2. ✅ `ST_Intersects` is more tolerant than `ST_Contains`
3. ✅ The combination of both should cover most cases
4. ⚠️ ST_DWithin could mask real problems

**If in the future we find cases where:**

- ST_MakeValid + ST_Intersects fail
- And the point is clearly inside the country
- And there is evidence of precision problems

**Then it would be useful to add ST_DWithin as a third fallback.**

## Implementation Example (If Needed)

```bash
# In __validate_capital_location, after ST_Intersects:

if [[ "${INTERSECTS_RESULT}" != "t" ]] && [[ "${INTERSECTS_RESULT}" != "true" ]]; then
  # Third attempt: ST_DWithin with 100 meters tolerance
  __logw "ST_Intersects also failed for boundary ${BOUNDARY_ID}, trying ST_DWithin with 100m tolerance"

  local DWITHIN_RESULT
  DWITHIN_RESULT=$(psql -d "${DB_NAME}" -Atq -c \
    "SELECT ST_DWithin(
      ST_SetSRID(ST_MakePoint(${CAPITAL_LON}, ${CAPITAL_LAT}), 4326)::geography,
      ST_MakeValid(ST_Union(geometry))::geography,
      100
    )
    FROM import
    WHERE ST_GeometryType(geometry) IN ('ST_Polygon', 'ST_MultiPolygon')
      AND NOT ST_IsEmpty(geometry);" \
    2> /dev/null || echo "false")

  if [[ "${DWITHIN_RESULT}" == "t" ]] || [[ "${DWITHIN_RESULT}" == "true" ]]; then
    __logw "Capital validation passed with ST_DWithin (100m tolerance) for boundary ${BOUNDARY_ID}"
    __logw "Capital is within 100 meters of the boundary - may indicate precision issues"
    return 0
  fi
fi
```

## Conclusion

**ST_DWithin** is a useful function for spatial validation with tolerance, but **it is not necessary
at this time** because:

- We already have `ST_MakeValid` to fix geometries
- We already have `ST_Intersects` as a more tolerant fallback
- ST_DWithin would add complexity without clear benefit
- Could hide real cross-contamination problems

**It is recommended to implement only if:**

- After using current improvements, there are still false negatives
- There is clear evidence of precision problems
- Problematic cases are near the edge (within 100m)

---

## Related Documentation

- **[Country_Assignment_2D_Grid.md](./Country_Assignment_2D_Grid.md)**: Country assignment strategy
  using spatial functions
- **[Process_Planet.md](./Process_Planet.md)**: Planet processing with country assignment
- **[bin/process/updateCountries.sh](../bin/process/updateCountries.sh)**: Country boundary
  processing script
- **[sql/README.md](../sql/README.md)**: SQL functions including `get_country()` function
- **[PostgreSQL_Setup.md](./PostgreSQL_Setup.md)**: PostGIS installation and setup

**Version:** 1.0  
**Date:** 2025-12-08
