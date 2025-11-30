# Country-Based Note Styling

## Overview

This document describes the enhanced SLD (Styled Layer Descriptor) files that allow
identifying OSM notes by country using different colors and shapes. This is
particularly useful in border areas where notes from different countries are
close together.

## Features

### Visual Differentiation

- **Color coding**: Each country gets a distinct base color based on its
  `id_country` value
- **Shape coding**: Different geometric shapes (triangle, circle, square, star,
  cross, arrow) are assigned based on `id_country % 6`
- **Age indication**: Color intensity still reflects note age (darker = older for
  open notes, lighter = older for closed notes)
- **Unclaimed areas**: Notes without country assignment (NULL) are displayed in
  gray

### Shape Assignment

The shape is determined by `id_country % 6`:

- **0**: Triangle (red/purple tones for open, dark gray for closed)
- **1**: Circle (orange tones for open, cyan for closed)
- **2**: Square (purple tones for open, teal for closed)
- **3**: Star (blue tones for open, green for closed)
- **4**: Cross (yellow/green tones for open, yellow for closed)
- **5**: Arrow (pink/magenta tones for open, light blue for closed)

## Files

### Database Update

- **`sql/wms/addCountryToWMS.sql`**: Adds `id_country` column to `wms.notes_wms`
  table and updates triggers to include country information

### SLD Files

- **`OpenNotesByCountry.sld`**: Styling for open notes with country
  identification
- **`ClosedNotesByCountry.sld`**: Styling for closed notes with country
  identification

## Installation

### Step 1: Update Database

The database schema has been updated in `sql/wms/prepareDatabase.sql` to include
country information. If you're setting up a new database, run:

```bash
psql -d your_database -f sql/wms/prepareDatabase.sql
```

If you have an existing database, you'll need to:

1. Add the new columns:
```sql
ALTER TABLE wms.notes_wms 
  ADD COLUMN IF NOT EXISTS id_country INTEGER,
  ADD COLUMN IF NOT EXISTS country_shape_mod INTEGER;

COMMENT ON COLUMN wms.notes_wms.id_country IS
  'Country id where the note is located (NULL for unclaimed/disputed areas)';
COMMENT ON COLUMN wms.notes_wms.country_shape_mod IS
  'Modulo 6 of id_country for shape assignment (0-5, NULL if no country)';
```

2. Update existing records:
```sql
UPDATE wms.notes_wms nw
SET 
  id_country = n.id_country,
  country_shape_mod = CASE 
    WHEN n.id_country IS NOT NULL THEN n.id_country % 6
    ELSE NULL
  END
FROM notes n
WHERE nw.note_id = n.note_id;
```

3. Update triggers (they are automatically updated in `prepareDatabase.sql`)

This will:
- Add `id_country` and `country_shape_mod` columns to `wms.notes_wms`
- Update existing records with country information from the `notes` table
- Modify triggers to include `id_country` and `country_shape_mod` in future updates

### Step 2: Update GeoServer Styles

1. Log into GeoServer
2. Navigate to **Styles** section
3. For each new SLD file:
   - Click **Add a new style**
   - Upload the SLD file (`OpenNotesByCountry.sld` or
     `ClosedNotesByCountry.sld`)
   - Name it appropriately (e.g., "Open Notes by Country")
   - Save

### Step 3: Update Layer Configuration

1. Navigate to **Layers** section
2. Select your notes layer
3. Go to **Publishing** tab
4. Under **WMS Settings - Layers Settings**:
   - Add the new style as an additional style
   - Or set it as the default style

### Step 4: Update SQL View (if using SQL views)

If you're using SQL views for your layers, update them to include `id_country` and
`country_shape_mod`:

**Open Notes:**
```sql
SELECT /* Notes-WMS */ 
  year_created_at, 
  year_closed_at, 
  id_country,
  country_shape_mod,
  geometry
FROM wms.notes_wms
WHERE year_closed_at IS NULL
ORDER BY year_created_at DESC
```

**Closed Notes:**
```sql
SELECT /* Notes-WMS */ 
  year_created_at, 
  year_closed_at, 
  id_country,
  country_shape_mod,
  geometry
FROM wms.notes_wms
WHERE year_closed_at IS NOT NULL
ORDER BY year_created_at DESC
```

**Note:** The `country_shape_mod` column is pre-calculated in the database (using
`id_country % 6`) to avoid needing the `Modulo` function in SLD filters, which
may not be supported by all WMS servers.

## Color Schemes

### Open Notes

- **Red/Purple tones** (Triangle): `#ff6b6b` → `#862e2e` (light to dark)
- **Orange tones** (Circle): `#ff8c42` → `#a02626` (light to dark)
- **Purple tones** (Square): `#a29bfe` → `#4834d4` (light to dark)
- **Blue tones** (Star): `#74b9ff` → `#0652dd` (light to dark)
- **Yellow/Green tones** (Cross): `#fdcb6e` → `#b84a2f` (light to dark)
- **Pink/Magenta tones** (Arrow): `#fd79a8` → `#d63384` (light to dark)
- **Gray** (No country): `#888888` → `#444444` (light to dark)

### Closed Notes

- **Dark Gray** (Triangle): `#2d3436` → `#b2bec3` (dark to light)
- **Cyan** (Circle): `#00b894` → `#81ecec` (dark to light)
- **Teal** (Square): `#00b894` → `#a8e6cf` (dark to light)
- **Green** (Star): `#00b894` → `#a8e6cf` (dark to light)
- **Yellow** (Cross): `#fdcb6e` → `#ffeaa7` (dark to light)
- **Light Blue** (Arrow): `#74b9ff` → `#dfe6e9` (dark to light)
- **Gray** (No country): `#888888` → `#cccccc` (dark to light)

## Age Categories

### Open Notes

- **0-1 years**: Lighter colors (recently opened)
- **1-2 years**: Medium colors
- **2+ years**: Darker colors (old notes)

### Closed Notes

- **Recently closed** (0-1 years ago): Darker colors
- **Old closed** (1+ years ago): Lighter colors

## Maintenance

### Updating Year Reference

The SLD files use a hardcoded year (currently 2025) for age calculations. To
update:

1. Search for `2025` in the SLD files
2. Replace with the current year
3. Re-upload to GeoServer

Alternatively, you can automate this with a script that updates the year
annually.

### Country Assignment

Ensure that notes have their `id_country` properly assigned. This is typically
done by:

1. Running the country assignment process (`processAPI` or `processPlanet`)
2. Verifying that the `notes.id_country` column is populated
3. Running the WMS update script to sync country information

## Benefits

1. **Border identification**: Easy to distinguish notes from different countries
   in border regions
2. **Visual clarity**: Different shapes and colors make it easier to scan maps
   for specific countries
3. **Unclaimed area visibility**: Gray notes clearly indicate areas without
   country assignment (international waters, disputed zones)
4. **Backward compatibility**: Age-based color intensity is preserved

## Verifying Modulo Function Support

The SLD files use a pre-calculated `country_shape_mod` column instead of the
`Modulo` function in filters. This ensures compatibility with all WMS servers.

If you want to verify whether your GeoServer supports the `Modulo` function
directly in SLD filters, you can:

1. **Test with a simple SLD rule:**
   Create a test SLD with a rule like:
   ```xml
   <ogc:Filter>
     <ogc:PropertyIsEqualTo>
       <ogc:Function name="Modulo">
         <ogc:PropertyName>id_country</ogc:PropertyName>
         <ogc:Literal>6</ogc:Literal>
       </ogc:Function>
       <ogc:Literal>0</ogc:Literal>
     </ogc:PropertyIsEqualTo>
   </ogc:Filter>
   ```

2. **Check GeoServer logs:**
   If the function is not supported, you'll see errors in the GeoServer logs
   when trying to render the layer.

3. **Use the pre-calculated column (recommended):**
   The current implementation uses `country_shape_mod` which is calculated in
   the database, ensuring compatibility with all WMS servers.

## Limitations

- The modulo-based shape assignment means countries with similar `id_country`
  values may have the same shape
- Color schemes are fixed and may not be optimal for colorblind users
- The year reference needs manual updates (consider automating)

## Future Enhancements

Possible improvements:

1. **Custom country mapping**: Allow mapping specific countries to specific
   colors/shapes
2. **Colorblind-friendly palettes**: Add alternative color schemes
3. **Dynamic year calculation**: Use server-side functions instead of hardcoded
   year
4. **SVG custom shapes**: Support custom SVG shapes for countries
5. **Legend generation**: Automatic legend generation based on country data

