# Styled Layer Descriptors Directory

## Overview

The `sld` directory contains Styled Layer Descriptor (SLD) files that define the
visual styling and cartographic representation of OSM notes data in web mapping
applications. These files control how notes are displayed on maps with different
visual styles for different note states.

## Directory Structure

### `/sld/`

Styled Layer Descriptor files for GeoServer layers:

- **`OpenNotes.sld`**: Styling for open/active OSM notes
  - Uses dynamic age calculation (`age_years` column)
  - Country-based color and shape differentiation
  - Variable opacity based on note age
  - Different colors and shapes per country for easy identification
- **`ClosedNotes.sld`**: Styling for closed/resolved OSM notes
  - Uses dynamic age calculation (`years_since_closed` column)
  - Country-based color and shape differentiation
  - Variable opacity based on time since closure
  - Different colors and shapes per country for easy identification
- **`CountriesAndMaritimes.sld`**: Styling for geographic boundaries and maritime areas
- **`DisputedAndUnclaimedAreas.sld`**: Styling for disputed and unclaimed areas

Documentation files:

- **`SLD_AND_SQL_RELATIONSHIP.md`**: Relationship between SLD files and SQL views
- **`SLD_UNIFICATION.md`**: Documentation of SLD unification process

## Software Components

### Cartographic Styling

- **Note States**: Different visual styles for open vs closed notes
- **Country Identification**: Different colors and shapes per country
- **Geographic Context**: Styling for country boundaries and maritime areas
- **Color Schemes**: Consistent color coding for different note types
- **Symbol Design**: Point symbols and line styles for map features
- **Variable Opacity**: Older notes are more transparent to reduce visual noise

### Web Mapping Integration

- **WMS Support**: Styled Layer Descriptors for Web Map Services
- **Interactive Maps**: Visual styling for web-based mapping applications
- **Data Visualization**: Clear representation of OSM notes data
- **User Interface**: Intuitive visual design for map users

### Data Representation

- **Note Status**: Visual indicators for note state (open/closed)
- **Country Differentiation**: Visual distinction by country using colors and shapes
- **Geographic Features**: Styling for administrative boundaries
- **Spatial Context**: Background layers for geographic reference
- **Interactive Elements**: Hover effects and click interactions

## Usage

These SLD files are used by web mapping applications to:

- Display OSM notes with appropriate visual styling
- Distinguish between open and closed notes
- Identify notes by country using different colors and shapes
- Provide geographic context with country boundaries
- Create intuitive and informative map visualizations

### Default Styles

The default styles (`OpenNotes.sld` and `ClosedNotes.sld`) are automatically
assigned to the `notesopen` and `notesclosed` layers in GeoServer. They use
dynamic age calculation, so no manual updates are required each year.

Both styles include country-based differentiation:
- Each country gets a distinct base color
- Different shapes per country (triangle, circle, square, star, cross, arrow)
- Shape is determined by `country_shape_mod` column (id_country % 6)
- Notes without country (NULL) are shown in gray

## Dynamic Age Calculation

All SLD files use dynamic age calculation from the database views:
- Open notes use the `age_years` column (calculated as `CURRENT_YEAR - year_created_at`)
- Closed notes use the `years_since_closed` column (calculated as `CURRENT_YEAR - year_closed_at`)

This means the styles automatically update each year without requiring manual SLD modifications.

## Country-Based Styling

The styles automatically differentiate notes by country:

- **Color coding**: Each country gets a distinct base color based on its `id_country` value
- **Shape coding**: Different geometric shapes (triangle, circle, square, star, cross, arrow) are assigned based on `id_country % 6`
- **Age indication**: Color intensity still reflects note age (darker = older for open notes, lighter = older for closed notes)
- **Unclaimed areas**: Notes without country assignment (NULL) are displayed in gray

This is particularly useful in border areas where notes from different countries are close together.

## Dependencies

- Web Map Server (GeoServer, MapServer, etc.)
- SLD-compatible mapping applications
- Geographic data visualization tools
- Web mapping libraries and frameworks
