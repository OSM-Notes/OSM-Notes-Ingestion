# Future Reevaluation Tasks

This document lists technical decisions and architectural choices that should be reconsidered once the system reaches a stable version.

## Directory Structure

- **Current**: Linux root-style structure (`bin/`, `etc/`, `sql/`, `tests/`, `docs/`)
- **Consideration**: Refactor to Maven-style structure (`main/tests/examples`)
- **Rationale**: `docs` and `tests` were not present from the beginning, and a more standard structure may improve maintainability

## Database Optimization

- **Current**: Database partitions for parallel processing
- **Consideration**: Evaluate other strategies like:
  - Sharding
  - Specialized indexes
  - Separate tables
- **Rationale**: Partitions were created to avoid lock contention, but other approaches may be more efficient at scale

## Processing Frequency

- **Current**: `processAPI` executed via daemon (`processAPINotesDaemon.sh`) running continuously in memory, checking every minute (default `DAEMON_SLEEP_INTERVAL=60` seconds)
- **Status**: ✅ **COMPLETED** - Frequency has been reduced to 1 minute for near real-time processing
- **Previous**: Was called every 15 minutes via cron
- **Implementation**: Daemon runs continuously in memory with adaptive sleep interval (default 60 seconds)
- **Note**: The daemon provides lower latency (30-60 seconds) compared to cron (15 minutes), and the system has been optimized to handle this higher frequency successfully

## Language and Dependencies

- **Current**: Bash with minimal dependencies, avoiding Python
- **Consideration**: Evaluate migration to Python or other languages for:
  - Better abstraction of parallelization
  - Improved text processing capabilities
  - Leveraging specialized libraries
- **Rationale**: While Bash works, some aspects could benefit from language-specific features

## Database Alternatives

- **Current**: PostgreSQL (same as OSM)
- **Consideration**: Evaluate MySQL as option B
- **Consideration**: Evaluate non-relational engines (MongoDB, etc.) for specific use cases
- **Rationale**: Current choice was pragmatic, but alternatives may offer benefits at scale

## Script Modularity

- **Current**: Independent scripts (`processPlanet`, `processAPI`) with shared library scripts
- **Consideration**: Further refactoring to improve modularity and reduce duplication
- **Rationale**: Scripts became very long and complex, requiring division. Further improvements may be needed

## Data Processing Pipeline

- **Current**: XML → CSV → Database pipeline
  - XML files are converted to CSV using AWK
  - CSV files are loaded into database using PostgreSQL COPY
- **Consideration**: Evaluate direct XML insertion to database
  - Eliminate CSV intermediate step
  - Use PostgreSQL XML functions for parsing
  - Stream large XML files directly to database
- **Requirements**: Before implementing, analyze:
  - Performance comparison (XML → DB vs XML → CSV → DB)
  - Memory usage with very large XML files (2.2GB+)
  - Error handling and recovery mechanisms
  - Parallel processing capabilities
- **Rationale**: CSV intermediate step was chosen for memory efficiency and bulk loading performance, but direct XML insertion could simplify the pipeline if performance is acceptable

## Performance Optimization

- **Current**: Basic performance optimizations in place
- **Consideration**: Comprehensive performance analysis when note volume increases significantly
- **Areas to analyze**:
  - Database query optimization
  - Parallel processing efficiency
  - Memory usage patterns
  - I/O bottlenecks

## Testing and Quality

- **Current**: Comprehensive test suite in place
- **Status**: ✅ **COMPLETED** - Performance testing suite has been implemented
  - Benchmark suite created: `performance_benchmarks.test.bats`
  - Automated metrics implemented
  - Version comparison functionality added
  - Results stored in JSON format
- **Consideration**: Continue optimizing test execution time (Phase 3, low priority)
- **Rationale**: Performance testing has been implemented. Future focus is on execution time optimization.

## Documentation

- **Current**: Complete documentation structure
- **Consideration**: Keep documentation updated as system evolves
- **Rationale**: Technical decisions should be documented as they are made

---

**Note**: These items should be evaluated after the first stable version is released. Priority should be given to items that impact scalability and maintainability.

