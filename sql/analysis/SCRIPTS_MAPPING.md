# Performance Analysis Scripts to Main Processes Mapping

This document maps each performance analysis script to its corresponding main process.

## Summary by Process

### 📦 `processPlanetNotes.sh` - Planet Notes Processing

This is the main process for loading historical notes from the complete Planet dump.

**Related analysis scripts:**

1. **`analyze_partition_loading_performance.sql`**
   - **Related SQL**: `sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql`
   - **Bash function**: `__loadPartitionedSyncNotes()` in `bin/lib/functionsProcess.sh`
   - **What it analyzes**: Performance of massive COPY operations to load partitions
   - **When it runs**: During initial loading of Planet notes in parallel partitions

2. **`analyze_partition_consolidation_performance.sql`**
   - **Related SQL**: `sql/process/processPlanetNotes_42_consolidatePartitions.sql`
   - **Bash function**: `__consolidatePartitions()` in `bin/lib/functionsProcess.sh`
   - **What it analyzes**: Performance of massive INSERT operations to consolidate partitions
   - **When it runs**: After loading all partitions, when consolidating into sync tables

3. **`analyze_integrity_verification_performance.sql`**
   - **Related SQL**: `sql/functionsProcess_33_verifyNoteIntegrity.sql`
   - **Bash function**: `__getLocationNotes()` → `__getLocationNotes_impl()` in `bin/lib/noteProcessingFunctions.sh`
   - **What it analyzes**: Performance of note location integrity verification
   - **When it runs**: During integrity verification (process that takes hours)
   - **Called from**: `processPlanetNotes.sh` after assigning countries

4. **`analyze_country_assignment_performance.sql`**
   - **Related SQL**: `sql/functionsProcess_37_assignCountryToNotesChunk.sql`
   - **Bash function**: `__getLocationNotes()` → `__getLocationNotes_impl()` in `bin/lib/noteProcessingFunctions.sh`
   - **What it analyzes**: Performance of country assignment to notes (massive UPDATE with get_country())
   - **When it runs**: During initial country assignment to Planet notes
   - **Called from**: `processPlanetNotes.sh` (automatically)

---

### 🔄 `processAPINotes.sh` - API Notes Processing

This is the main process for synchronizing recent notes from the OSM API.

**Related analysis scripts:**

1. **`analyze_partition_loading_performance.sql`**
   - **Related SQL**: `sql/process/processAPINotes_31_loadApiNotes.sql`
   - **Bash function**: `__loadApiNotes()` in `bin/lib/processAPIFunctions.sh`
   - **What it analyzes**: Performance of massive COPY operations to load API data into partitions
   - **When it runs**: During loading of notes from API in parallel partitions

2. **`analyze_api_insertion_performance.sql`**
   - **Related SQL**: `sql/process/processAPINotes_32_insertNewNotesAndComments.sql`
   - **Bash function**: `__insertNewNotesAndComments()` in `bin/process/processAPINotes.sh`
   - **What it analyzes**: Performance of note insertion using cursors and stored procedures
   - **When it runs**: When inserting new notes and comments from API tables to main tables

3. **`analyze_partition_consolidation_performance.sql`**
   - **Related SQL**: `sql/process/processAPINotes_35_consolidatePartitions.sql`
   - **Bash function**: `__consolidatePartitions()` in `bin/process/processAPINotes.sh`
   - **What it analyzes**: Performance of API partition consolidation
   - **When it runs**: After loading API partitions, when consolidating into main API tables

---

### 🌍 `updateCountries.sh` - Country Boundaries Update

This process updates country boundaries when they change in OSM.

**Related analysis scripts:**

1. **`analyze_country_reassignment_performance.sql`**
   - **Related SQL**: `sql/functionsProcess_36_reassignAffectedNotes.sql`
   - **Bash function**: `__reassignAffectedNotes()` in `bin/process/updateCountries.sh`
   - **What it analyzes**: Performance of country reassignment using spatial queries with bounding box
   - **When it runs**: When country boundaries are updated and affected notes need to be reassigned

---

### 📍 Country Assignment to Notes (Integrated in processPlanetNotes.sh)

This process assigns countries to notes that don't have a country assigned. It runs automatically during `processPlanetNotes.sh`.

**Related analysis scripts:**

1. **`analyze_country_assignment_performance.sql`**
   - **Related SQL**: `sql/functionsProcess_37_assignCountryToNotesChunk.sql`
   - **Bash function**: `__getLocationNotes()` → `__getLocationNotes_impl()` in `bin/lib/noteProcessingFunctions.sh`
   - **What it analyzes**: Performance of country assignment to notes (massive UPDATE with get_country())
   - **When it runs**: Automatically during `processPlanetNotes.sh` after creating the `get_country()` function

---

## Summary Table

| Analysis Script | Main Process | Related SQL | Bash Function |
|----------------|--------------|-------------|---------------|
| `analyze_partition_loading_performance.sql` | `processPlanetNotes.sh` | `processPlanetNotes_41_loadPartitionedSyncNotes.sql` | `__loadPartitionedSyncNotes()` |
| `analyze_partition_loading_performance.sql` | `processAPINotes.sh` | `processAPINotes_31_loadApiNotes.sql` | `__loadApiNotes()` |
| `analyze_partition_consolidation_performance.sql` | `processPlanetNotes.sh` | `processPlanetNotes_42_consolidatePartitions.sql` | `__consolidatePartitions()` |
| `analyze_partition_consolidation_performance.sql` | `processAPINotes.sh` | `processAPINotes_35_consolidatePartitions.sql` | `__consolidatePartitions()` |
| `analyze_api_insertion_performance.sql` | `processAPINotes.sh` | `processAPINotes_32_insertNewNotesAndComments.sql` | `__insertNewNotesAndComments()` |
| `analyze_integrity_verification_performance.sql` | `processPlanetNotes.sh` | `functionsProcess_33_verifyNoteIntegrity.sql` | `__getLocationNotes()` |
| `analyze_country_assignment_performance.sql` | `processPlanetNotes.sh` | `functionsProcess_37_assignCountryToNotesChunk.sql` | `__getLocationNotes()` |
| `analyze_country_reassignment_performance.sql` | `updateCountries.sh` | `functionsProcess_36_reassignAffectedNotes.sql` | `__reassignAffectedNotes()` |

---

## When to Run the Analyses

### Analysis for `processPlanetNotes.sh`

Run after:

- ✅ Initial Planet notes loading
- ✅ Partition consolidation
- ✅ Country assignment
- ✅ Integrity verification

**Command:**

```bash
# Run specific analyses for Planet
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes
```

### Analysis for `processAPINotes.sh`

Run after:

- ✅ Each API synchronization (typically every 15 minutes)
- ✅ API partition loading
- ✅ API partition consolidation
- ✅ New note insertion

**Command:**

```bash
# Run specific analyses for API
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes
```

### Analysis for `updateCountries.sh`

Run after:

- ✅ Country boundary updates
- ✅ Affected notes reassignment

**Command:**

```bash
# Run specific analyses for country update
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes
```

---

## Important Notes

1. **Some analyses are shared**:

   - `analyze_partition_loading_performance.sql` is used for both Planet and API
   - `analyze_partition_consolidation_performance.sql` is used for both Planet and API
   - `analyze_country_assignment_performance.sql` is used in multiple processes

2. **Most critical analyses**:

   - `analyze_integrity_verification_performance.sql`: Process that takes hours, critical to optimize
   - `analyze_country_assignment_performance.sql`: Runs frequently, affects overall performance

3. **Recommended frequency**:

   - **Planet**: After each complete load (weeks/months)
   - **API**: After each synchronization or daily
   - **Countries**: After each boundary update
