# ADR-0002: Use PostgreSQL with PostGIS

## Status

Accepted

## Context

We need to store OSM notes data, which includes geographic information (coordinates, geometries). We need a database system that can efficiently handle spatial data and queries.

## Decision

We will use PostgreSQL with the PostGIS extension as the primary database system for storing OSM notes data.

## Consequences

### Positive

- **Spatial capabilities**: PostGIS provides excellent support for geographic data
- **Mature and stable**: PostgreSQL and PostGIS are well-established, production-ready technologies
- **Open source**: No licensing costs
- **Rich ecosystem**: Many tools and libraries support PostgreSQL/PostGIS
- **Performance**: Efficient spatial indexing and queries
- **Standard SQL**: Uses standard SQL with spatial extensions

### Negative

- **Learning curve**: Team needs to learn PostGIS spatial functions
- **Resource usage**: Spatial indexes require additional storage and memory
- **Complexity**: Spatial queries can be complex

## Alternatives Considered

### Alternative 1: MySQL with spatial extensions

- **Description**: Use MySQL with its spatial data types
- **Pros**: Widely used, good performance
- **Cons**: Less mature spatial support than PostGIS, fewer spatial functions
- **Why not chosen**: PostGIS has superior spatial capabilities

### Alternative 2: MongoDB with GeoJSON

- **Description**: Use MongoDB for document storage with GeoJSON
- **Pros**: Flexible schema, good for document data
- **Cons**: Less mature spatial querying, ACID guarantees weaker, not ideal for relational data
- **Why not chosen**: Notes data is relational, and we need strong ACID guarantees

### Alternative 3: Spatial databases (PostGIS, SpatiaLite)

- **Description**: Use specialized spatial databases
- **Pros**: Optimized for spatial data
- **Cons**: Less general-purpose, smaller ecosystem
- **Why not chosen**: PostgreSQL + PostGIS provides the best balance of general-purpose and spatial capabilities

## References

- [PostGIS Documentation](https://postgis.net/documentation/)
- [PostgreSQL Spatial Features](https://www.postgresql.org/docs/current/datatype-geometric.html)
