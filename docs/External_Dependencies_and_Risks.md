# External Dependencies and Risks

> This document describes critical external dependencies and risks that could
> affect the OSM-Notes-Ingestion project. Understanding these dependencies is
> crucial for system maintenance, troubleshooting, and future planning.

## Table of Contents

- [Overview](#overview)
- [OSM Notes API Dependencies](#osm-notes-api-dependencies)
- [OSM Planet Dump Dependencies](#osm-planet-dump-dependencies)
- [Overpass API Dependencies](#overpass-api-dependencies)
- [OSM Database Direct Access](#osm-database-direct-access)
- [Impact Assessment](#impact-assessment)
- [Mitigation Strategies](#mitigation-strategies)
- [Related Documentation](#related-documentation)

---

## Overview

The OSM-Notes-Ingestion project relies on several external services and data
sources provided by OpenStreetMap and the OSM community. Changes to these
external dependencies could significantly impact the project's functionality.

This document identifies:

- **Critical Dependencies**: External services that the project cannot function
  without
- **Risks**: Potential changes or disruptions that could affect the project
- **Impact**: How these changes would affect different components
- **Alternatives**: Potential workarounds or alternative approaches

---

## OSM Notes API Dependencies

### Current API Usage

The project heavily depends on the OSM Notes API (version 0.6) for incremental
synchronization of notes data. The main use case is downloading notes from the
entire world using only date filters.

**Critical Dependency**: The project's ability to download notes with date
filters is essential for maintaining near real-time synchronization.

### API Filter Limitations

**Important**: The project primarily uses date-based filters for downloading
notes. Other filter types available in the API are not suitable for the
project's use case:

- **Date Filters**: ✅ Used successfully for incremental synchronization
- **Other Filters**: ❌ Not suitable for the project's requirements

### API Version Detection

The OSM API version can be detected in multiple ways:

1. **URL Path**: The version is embedded in the API URL path:
   - Current: `https://api.openstreetmap.org/api/0.6/notes`
   - The version (`0.6`) is part of the URL structure

2. **Versions Endpoint**: The OSM API provides a dedicated endpoint to query the API version:
   - Endpoint: `https://api.openstreetmap.org/api/versions`
   - Response format:
     ```xml
     <?xml version="1.0" encoding="UTF-8"?>
     <osm generator="OpenStreetMap server" ...>
       <api>
         <version>0.6</version>
       </api>
     </osm>
     ```
   - This is the **preferred method** for version detection as it doesn't require making a data request

3. **XML Response**: The API response includes the version in the root element:
   ```xml
   <osm version="0.6" generator="OpenStreetMap server">
   ```
   - The `version` attribute in the `<osm>` element indicates the API version
   - This requires making an API request to obtain

**Current Implementation**: The project uses the `/api/versions` endpoint to detect and validate the API version during prerequisites check. This ensures that:
- The API version is correctly detected without making unnecessary data requests
- Version mismatches are caught early before processing begins
- The detected version is compared against the expected version (0.6)

The project stores the API version in the `OSM_API` configuration variable (e.g., `https://api.openstreetmap.org/api/0.6`), but also validates it dynamically using the `/api/versions` endpoint.

**Future Consideration**: If API version detection becomes necessary for compatibility:

- The project already implements automatic version detection via `/api/versions`
- Version mismatches are detected and reported during prerequisites check
- Compatibility layers for different API versions can be implemented based on detected version

### Risk: API Changes

**High Risk**: If the OSM Notes API changes (e.g., API version upgrade from 0.6
to 0.7 or 1.0), the project could fail, especially:

- **Date Filter Functionality**: If date-based filtering is removed or changed,
  the incremental synchronization mechanism would break
- **API Response Format**: Changes to XML structure would require updates to
  AWK scripts and validation logic
- **Rate Limits**: Changes to rate limiting could affect synchronization
  frequency

**Impact**:

- The `processAPINotes.sh` script would fail to download notes
- Incremental synchronization would stop working
- The system would fall back to Planet dumps only (if available)

**Mitigation**:

- Monitor OSM API announcements and deprecation notices
- Test API changes in development environment before production
- Maintain flexibility in XML processing (AWK scripts can be updated)
- Consider implementing API version detection and compatibility layers

**Note**: The project automatically validates OSM API version (0.6) and network
connectivity during prerequisites check. See [Prerequisites Validation](./Documentation.md#prerequisites-validation) in the Documentation for details.

### Risk: Historical Notes Download via API

**Medium Risk**: If the OSM API begins offering the ability to download the
complete historical notes dataset (all notes since 2013), this would result in
a massive XML file.

**Impact**:

- The project's ingestion approach would lose relevance
- The current incremental synchronization strategy would become less valuable
- Users might prefer direct API access over the ingestion pipeline

**Consideration**:

- If OSM provides complete historical data via API, the project's value
  proposition would need to be re-evaluated
- The project might shift focus to analytics and data processing rather than
  data collection
- The current architecture could still provide value through:
  - Pre-processed and optimized data
  - Country assignment and spatial analysis
  - Historical tracking and analytics
  - WMS layer services

---

## OSM Planet Dump Dependencies

### Current Planet Dump Usage

The project depends on daily Planet dumps for:

- Initial database population
- Gap correction and data integrity verification
- Synchronization when API returns >10,000 notes

**Critical Dependency**: Daily Planet dumps are essential for:

- Correcting data gaps (GAPs) that may occur between API calls
- Maintaining data integrity and completeness
- Providing a reliable fallback when API synchronization fails

**Primary Source**: The project downloads Planet dumps from:

- **Official OSM Planet Server**: `https://planet.openstreetmap.org/planet/notes/`
- **Daily Updates**: Planet notes dumps are published daily
- **File Format**: `planet-notes-latest.osn.bz2` (compressed XML)

### Alternative Sources for Historical Dumps

**Archive.org**: Some historical Planet dumps may be available on
[archive.org](https://archive.org), but with important limitations:

- **Not Recent**: Archive.org typically does not contain the most recent dumps
- **Incomplete Coverage**: Historical dumps may not be available for all dates
- **Not Official Source**: Archive.org is not an official OSM mirror
- **Use Case**: Primarily useful for historical research or recovery of very old
  data, not for current operations

**Official Mirrors**: For more recent historical dumps, official OSM mirrors may
provide better coverage:

- **GWDG Mirror**: `ftp.gwdg.de/pub/misc/openstreetmap/planet.openstreetmap.org/`
- **Other Mirrors**: Various geographic mirrors maintained by the OSM community

**Recommendation**: For production use, always rely on the official OSM Planet
server. Archive.org and mirrors should only be considered as fallback options
for historical data recovery when official sources are unavailable.

### Risk: Planet Dump Discontinuation

**High Risk**: If daily Planet dumps are no longer published, the project
would face significant challenges:

**Impact**:

- **Gap Correction**: No way to identify and correct missing notes between API
  calls
- **Data Integrity**: Cannot verify completeness of ingested data
- **Synchronization**: Cannot perform full synchronization when API threshold
  (10,000 notes) is exceeded
- **Initial Load**: New installations would have no way to populate historical
  data

**Specific Problems**:

1. **GAP Detection**: Without Planet dumps, there's no reliable way to detect
   missing notes between API synchronization cycles
2. **Synchronization Verification**: Cannot compare API data with Planet data to
   ensure consistency
3. **Data Recovery**: If API synchronization fails for an extended period,
   there's no way to recover missing data
4. **API-Planet Synchronization**: Cannot maintain synchronization level
   between API and Planet data sources

**Mitigation**:

- Monitor OSM Planet publication status
- Implement alternative gap detection mechanisms (if possible)
- Consider archiving Planet dumps locally for historical reference
- Document manual recovery procedures for data gaps

---

## Overpass API Dependencies

### Current Overpass Usage

The project uses Overpass API to download:

- Country boundaries (administrative relations)
- Maritime boundaries (maritime relations)

**Critical Dependency**: Overpass queries are essential for:

- Initial country and maritime boundary setup
- Monthly boundary updates (`updateCountries.sh`)
- Spatial analysis and country assignment for notes

### Risk: Overpass Replacement

**Medium Risk**: The Overpass query interface could eventually be replaced by:

- **DPF (Differential Planet Files)**: Pre-processed planet files with
  specific data extracts
- **Sophox**: Alternative query interface for OSM data

**Impact**:

- The project structure would need significant changes
- Query syntax and data format would differ
- Download mechanisms and rate limiting would need to be re-implemented
- Boundary processing scripts would require major refactoring

**Affected Components**:

- `bin/lib/overpassFunctions.sh`: Overpass query execution
- `bin/lib/boundaryProcessingFunctions.sh`: Boundary download and processing
- `overpass/countries.op`: Overpass query for countries
- `overpass/maritimes.op`: Overpass query for maritime boundaries
- `bin/process/updateCountries.sh`: Monthly boundary update script

**Mitigation**:

- Design abstraction layer for query interfaces
- Monitor OSM community discussions about Overpass alternatives
- Plan migration strategy if replacement is announced
- Consider supporting multiple query interfaces simultaneously

---

## OSM Database Direct Access

### Current Architecture

The project currently:

- Downloads data from OSM API and Planet dumps
- Processes and transforms data locally
- Stores processed data in PostgreSQL database
- Provides analytics and WMS services

### Potential: Direct OSM Database Access

**Future Consideration**: If direct access to the OSM database becomes
available, this would significantly change the project landscape.

**Impact on OSM-Notes-Analytics**:

If the OSM database can be queried directly:

- The sibling project [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics)
  could download data directly from the OSM database
- The complex data ingestion pipeline in this project would become less
  necessary for analytics purposes
- Analytics could query OSM data in real-time without the ingestion overhead

**Impact on This Project**:

- **Reduced Relevance for Analytics**: If Analytics can access OSM database
  directly, this project's value for analytics would decrease
- **Remaining Value**: This project would still provide value through:
  - Pre-processed and optimized data structures
  - Country assignment and spatial analysis
  - Historical tracking and change detection
  - WMS layer services
  - Data transformation and normalization

**Consideration**:

- Direct database access is unlikely to be provided by OSM Foundation due to:
  - Performance and load concerns
  - Security and access control requirements
  - Database stability and maintenance requirements
- If provided, it would likely be:
  - Read-only access
  - Rate-limited
  - Require authentication and authorization
  - Limited to specific use cases

---

## Impact Assessment

### Critical Dependencies Summary

| Dependency | Criticality | Risk Level | Impact if Lost |
|------------|-------------|------------|----------------|
| OSM Notes API (date filters) | **Critical** | **High** | Incremental sync fails |
| Daily Planet dumps | **Critical** | **High** | Gap correction impossible |
| Overpass API | **Important** | **Medium** | Boundary updates fail |
| OSM Database access | **N/A** | **Low** | Not currently used |

### Component Impact Matrix

| Component | API Change | Planet Discontinuation | Overpass Replacement |
|-----------|------------|------------------------|----------------------|
| `processAPINotes.sh` | ❌ **Fails** | ⚠️ **Degraded** | ✅ **Unaffected** |
| `processPlanetNotes.sh` | ✅ **Unaffected** | ❌ **Fails** | ✅ **Unaffected** |
| `updateCountries.sh` | ✅ **Unaffected** | ✅ **Unaffected** | ❌ **Fails** |
| Gap correction | ⚠️ **Degraded** | ❌ **Impossible** | ✅ **Unaffected** |
| WMS layer | ✅ **Unaffected** | ✅ **Unaffected** | ✅ **Unaffected** |

**Legend**:

- ❌ **Fails**: Component would stop working
- ⚠️ **Degraded**: Component would work with reduced functionality
- ✅ **Unaffected**: Component would continue working normally

---

## Mitigation Strategies

### Monitoring and Early Warning

1. **API Monitoring**:
   - Subscribe to OSM API announcements
   - Monitor API deprecation notices
   - Test API changes in development environment

2. **Planet Dump Monitoring**:
   - Automate daily Planet dump availability checks
   - Alert if dumps are delayed or missing
   - Archive dumps locally for historical reference

3. **Overpass Monitoring**:
   - Monitor Overpass API status and announcements
   - Track OSM community discussions about alternatives
   - Test alternative query interfaces in development

### Code Flexibility

1. **Abstraction Layers**:
   - Design query interfaces that can be swapped
   - Implement adapter patterns for different data sources
   - Maintain separation between data source and processing logic

2. **Configuration Management**:
   - Externalize API endpoints and query formats
   - Support multiple API versions simultaneously
   - Make data source selection configurable

3. **Error Handling**:
   - Implement graceful degradation when dependencies fail
   - Provide clear error messages for dependency issues
   - Log dependency failures for analysis

### Documentation and Communication

1. **Dependency Documentation**:
   - Keep this document updated with current dependencies
   - Document workarounds for known issues
   - Provide migration guides for API changes

2. **Community Engagement**:
   - Participate in OSM API discussions
   - Provide feedback on proposed API changes
   - Contribute to OSM community planning

---

## Related Documentation

### Core Documentation

- **[Rationale.md](./Rationale.md)**: Project motivation and design decisions,
  including known limitations
- **[Component_Dependencies.md](./Component_Dependencies.md)**: Internal
  component dependencies and relationships
- **[Documentation.md](./Documentation.md)**: Complete system architecture and
  technical implementation

### Processing Documentation

- **[Process_API.md](./Process_API.md)**: API processing implementation and
  API dependency details
- **[Process_Planet.md](./Process_Planet.md)**: Planet processing
  implementation and Planet dump dependency details

### Troubleshooting Documentation

- **[Troubleshooting_Guide.md](./Troubleshooting_Guide.md)**: Troubleshooting
  guide for common issues, including dependency-related problems

### Planning Documentation

- **[ToDo/FUTURE_REEVALUATION.md](../ToDo/FUTURE_REEVALUATION.md)**: Items to
  be reconsidered in future versions, including dependency-related improvements

---

## Version History

- **2025-12-13**: Initial version documenting external dependencies and risks
