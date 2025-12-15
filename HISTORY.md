# Project History

## Origin: OpenNotesLatam (ONL) Awards Preparation

This project has its origins in the **OpenNotesLatam (ONL)** initiative, a
community project focused on resolving OpenStreetMap notes in Latin America.
The initial work was documented in the OpenStreetMap Wiki page:

**ES:LatAm/Proyectos/Resolución de notas/Preparación premios**

- **Wiki URL:**
  https://wiki.openstreetmap.org/wiki/ES:LatAm/Proyectos/Resoluci%C3%B3n_de_notas/Preparaci%C3%B3n_premios

### Initial Motivation (2022)

The project started as a way to identify and recognize contributors who were
actively resolving notes in Latin America. The goal was to:

1. Process notes from the OSM Planet for analysis in a database
2. Identify notes that belong to Latin America countries
3. Generate analytics and statistics about note resolution performance
4. Award recognition, badges, and prizes to active contributors

### Initial Processing Steps

The original approach documented in the wiki involved these steps:

1. **Install PostgreSQL** - Database setup
2. **Create Postgres database** - Isolated environment
3. **Activate PostGIS extension** - Geographic capabilities
4. **Install ogr2ogr** - GeoJSON to Postgres processing
5. **Install Java and Saxon** - XSLT 2.0 processing for XML conversion
6. **Create database model tables**:
   - `countries` - Country boundaries with geometries
   - `comment_actions` - Action types (opened, commented, closed, reopened)
   - `users` - User information
   - `notes` - Notes with location and timestamps
   - `comments` - Comments/actions on notes
7. **Insert Latin America country areas** - GeoJSON boundaries
8. **Download Planet notes file** - Full historical data
9. **Process notes file** - Convert XML to CSV using XSLT
10. **Insert into database** - Load processed data
11. **Identify LatAm notes** - Geographic association
12. **Execute analysis queries** - Performance metrics

### Challenges and Evolution

The initial approach faced several challenges:

- **Time-consuming processing**: Identifying note locations for millions of
  notes required significant computational resources
- **Manual XSLT conversion**: Required Java and Saxon for XML processing
- **Limited scalability**: Designed for batch processing, not real-time
- **No incremental updates**: Full Planet dump required for each update

### Evolution to Current System

Over time, the project evolved to address these limitations:

#### Technical Improvements

1. **AWK-based XML processing**: Replaced XSLT/Java with efficient AWK scripts
   for faster, memory-efficient XML to CSV conversion
2. **Incremental API synchronization**: Real-time updates via OSM API instead
   of full Planet dumps
3. **Parallel processing**: Optimized country assignment using parallel threads
4. **Modular architecture**: Separated concerns into distinct components
   (ingestion, analytics, visualization)
5. **Comprehensive testing**: Added 101 test suites for reliability
6. **Daemon mode**: Continuous processing with adaptive sleep logic

#### Project Structure Evolution

The project has been split into specialized components:

- **OSM-Notes-Ingestion** (this repository): Data ingestion and WMS services
- **OSM-Notes-Analytics**: Data warehouse, ETL, and profile generation
- **OSM-Notes-Viewer**: Web visualization and interactive exploration

This separation allows each component to focus on its specific domain while
maintaining clear interfaces between them.

#### Key Architectural Decisions

1. **Database-driven country assignment**: Using PostGIS for efficient spatial
   queries instead of manual GeoJSON processing
2. **Hybrid data sources**: Combining Planet dumps (historical) with API calls
   (incremental) for optimal performance
3. **Connection pooling**: Efficient database connection management for
   high-throughput processing
4. **Comprehensive monitoring**: Data integrity checks and gap detection
   systems

### Recognition System

The original recognition categories from the wiki are still relevant:

#### Awards

- **By Country**:
  - Comprometido con sus notas (Most committed)
  - Escuchando a sus usuarios (Listening to users)
  - Solo notas recientes (Recent notes only)
  - Lista vacía (Empty list - zero open notes)
  - Mejor atención a usuarios (Best user attention)

- **By Volunteer**:
  - Organizado (Organized - closed own notes)
  - Mejor Entusiasta (Best Enthusiast - new contributors)
  - Multinacional (Multinational - multiple countries)

#### Badges

- Excavador (Excavator)
- Arqueologista (Archaeologist)
- Epic
- Legendario (Legendary)
- Yearly
- Civic duty
- Sherif (Sheriff)
- Internacional (International)
- Talkative
- Disciplinado (Disciplined)

These analytics and recognition features are now implemented in the
[OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics)
repository.

### Current Status

Today, OSM-Notes-Ingestion is a production-ready system that:

- Processes millions of notes efficiently
- Maintains near real-time synchronization with OSM
- Provides WMS layers for geographic visualization
- Handles data integrity and monitoring automatically
- Supports both incremental (API) and bulk (Planet) processing
- Includes comprehensive testing and documentation

### References

- **Original Wiki**: https://wiki.openstreetmap.org/wiki/ES:LatAm/Proyectos/Resoluci%C3%B3n_de_notas/Preparaci%C3%B3n_premios
- **OSM Notes Analytics**: https://github.com/OSMLatam/OSM-Notes-Analytics
- **OSM Notes Viewer**: https://github.com/OSMLatam/OSM-Notes-Viewer
- **Project Rationale**: See [docs/Rationale.md](./docs/Rationale.md)


