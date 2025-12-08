# Overpass API Queries Directory

## Overview

The `overpass` directory contains Overpass API query files used to extract
geographic and administrative data from OpenStreetMap. These queries support the
OSM-Notes-Ingestion system by providing country boundaries, maritime areas, and
other geographic reference data.

## Directory Structure

### `/overpass/`

Overpass API query files:

- **`countries.op`**: Query to extract country boundaries and administrative data
- **`maritimes.op`**: Query to extract maritime areas and water bodies

## Software Components

### Geographic Data Extraction

- **Country Boundaries**: Administrative boundaries for country identification
- **Maritime Areas**: Water bodies and maritime zones
- **Administrative Data**: Country codes, names, and hierarchical relationships
- **Geographic Features**: Natural and man-made geographic features

### Data Processing Support

- **Country Resolution**: Associates OSM notes with countries based on coordinates
- **Geographic Analysis**: Supports spatial analysis and reporting
- **Data Enrichment**: Adds geographic context to OSM notes
- **Boundary Validation**: Validates note locations against administrative boundaries

### Integration with OSM Notes

- **Location Services**: Provides geographic context for note locations
- **Country Assignment**: Automatically assigns notes to countries
- **Regional Analysis**: Supports regional and country-level reporting
- **Spatial Queries**: Enables location-based note filtering and analysis

## Usage

These Overpass queries are used by the processing scripts to:

- Extract country boundaries for note location analysis
- Provide geographic context for OSM notes
- Support country-based reporting and analytics
- Enable spatial analysis of note distribution

## Query Examples

### Countries Query (`countries.op`)

Extracts all country boundary relations (admin_level=2):

```overpass
[out:csv(::id)];
(
  relation["type"="boundary"]["boundary"="administrative"]["admin_level"="2"];
);
out ids;
```

**Usage in scripts**:
```bash
# Query is executed by updateCountries.sh
./bin/process/updateCountries.sh
```

**Output**: CSV list of relation IDs for all countries

### Maritime Boundaries Query (`maritimes.op`)

Extracts all maritime boundary relations:

```overpass
[out:csv(::id)];
(
  relation["boundary"="maritime"];
);
out ids;
```

**Usage in scripts**:
```bash
# Query is executed by updateCountries.sh
./bin/process/updateCountries.sh
```

**Output**: CSV list of relation IDs for maritime areas (EEZ, territorial seas, etc.)

### Custom Overpass Query Example

Example of querying a specific country boundary:

```overpass
[out:json];
(
  relation["type"="boundary"]["boundary"="administrative"]["admin_level"="2"]["ISO3166-1"="CO"];
);
out geom;
```

This query returns the geometry for Colombia (ISO code CO) in JSON format.

## Rate Limiting and Best Practices

### Overpass API Rate Limits

The Overpass API has rate limits to prevent abuse:

- **Public Overpass instances**: Limited to ~4 requests per minute per IP
- **Two servers available**: Each server has 4 slots, total 8 concurrent slots
- **HTTP 429 errors**: Returned when rate limit is exceeded

### Rate Limiting Implementation

The processing scripts implement several mechanisms to respect rate limits:

**Semaphore Pattern**:
- Limits concurrent downloads to 8 slots (2 servers × 4 slots)
- Uses atomic file operations (`flock`, `mkdir`) to acquire/release slots
- Automatically cleans up stale locks from crashed processes

**FIFO Queue System**:
- Ensures orderly processing of boundary downloads
- Prevents race conditions in parallel processing
- Thread-safe ticket-based queue management

**Smart Waiting**:
- Checks Overpass API status before downloading
- Waits for available slots when API is busy
- Implements exponential backoff for HTTP 429 errors

**Configuration**:
```bash
# Configure rate limit (default: 8)
export RATE_LIMIT=8

# Configure backoff delay (default: 20 seconds)
export OVERPASS_BACKOFF_SECONDS=20
```

### Handling Rate Limit Errors

When HTTP 429 (Too Many Requests) is detected:

1. Script waits 30 seconds before retry
2. Implements exponential backoff for subsequent retries
3. Logs rate limit warnings for monitoring
4. Continues processing other boundaries while waiting

**Example error handling**:
```bash
# Rate limit detected in logs
ERROR 429: Too many requests to Overpass API for boundary 12345
Waiting 30s due to rate limit (429) before retry...
```

### Best Practices

1. **Use FIFO Queue**: Always use the queue system for parallel downloads
2. **Respect Limits**: Don't bypass rate limiting mechanisms
3. **Monitor Logs**: Watch for 429 errors and adjust `RATE_LIMIT` if needed
4. **Use Own Instance**: For high-volume processing, consider running your own Overpass instance
5. **Batch Processing**: Process boundaries in batches to avoid overwhelming the API

### Example: Executing Queries Safely

```bash
# The scripts handle rate limiting automatically
./bin/process/updateCountries.sh

# Manual query execution (respect rate limits!)
curl -X POST https://overpass-api.de/api/interpreter \
  --data-urlencode "data@countries.op" \
  -o countries.csv

# Wait between requests if making multiple calls
sleep 15  # Wait 15 seconds between requests
```

## Dependencies

- Overpass API access (public or private instance)
- Geographic data processing tools (ogr2ogr, GDAL)
- Spatial analysis libraries (PostGIS)
- Coordinate system handling (WGS84)
- Rate limiting mechanisms (implemented in processing scripts)
