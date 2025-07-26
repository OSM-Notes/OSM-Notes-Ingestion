# Styled Layer Descriptors Directory

## Overview
The `sld` directory contains Styled Layer Descriptor (SLD) files that define the visual styling and cartographic representation of OSM notes data in web mapping applications. These files control how notes are displayed on maps with different visual styles for different note states.

## Directory Structure

### `/sld/`
Styled Layer Descriptor files:
- **`OpenNotes.sld`**: Styling for open/active OSM notes
- **`ClosedNotes.sld`**: Styling for closed/resolved OSM notes
- **`CountriesAndMaritimes.sld`**: Styling for geographic boundaries and maritime areas

## Software Components

### Cartographic Styling
- **Note States**: Different visual styles for open vs closed notes
- **Geographic Context**: Styling for country boundaries and maritime areas
- **Color Schemes**: Consistent color coding for different note types
- **Symbol Design**: Point symbols and line styles for map features

### Web Mapping Integration
- **WMS Support**: Styled Layer Descriptors for Web Map Services
- **Interactive Maps**: Visual styling for web-based mapping applications
- **Data Visualization**: Clear representation of OSM notes data
- **User Interface**: Intuitive visual design for map users

### Data Representation
- **Note Status**: Visual indicators for note state (open/closed)
- **Geographic Features**: Styling for administrative boundaries
- **Spatial Context**: Background layers for geographic reference
- **Interactive Elements**: Hover effects and click interactions

## Usage
These SLD files are used by web mapping applications to:
- Display OSM notes with appropriate visual styling
- Distinguish between open and closed notes
- Provide geographic context with country boundaries
- Create intuitive and informative map visualizations

## Dependencies
- Web Map Server (GeoServer, MapServer, etc.)
- SLD-compatible mapping applications
- Geographic data visualization tools
- Web mapping libraries and frameworks 