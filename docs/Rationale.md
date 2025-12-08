# OSM Notes Ingestion - Project Rationale

## Why This Project Exists

Notes have been an internal part of OpenStreetMap since 2013. They have become more important because they are considered feedback from our users. Also, by solving notes, it expresses that the map is alive, where feedback is considered, and OSM mappers are listening to the users.

Many mappers are resolving notes, and new ones are starting to get involved in this process. For this reason, many questions are appearing, and new tools are being developed.

## The Problem with Current Note Management

### Limited Visibility and Analytics

The OpenStreetMap website does not offer a straightforward way to see notes created from a particular user (one should navigate the user and move forward through pages). This list does not provide information about where the note was created. Also, this website does not provide a list grouping notes by communities, like countries. Showing notes for a particular place helps engage mappers to close the notes in that area.

### Current Third-Party Alternatives

There are several third-party alternatives, but each has limitations:

* **[ResultMaps from Pascal Neis](https://resultmaps.neis-one.org/osm-notes)** is a valuable tool to identify notes, open and close ones. It supplies a list of notes for a specific country, as well as some statistics per country. Finally, it has a board about the users that are opening and closing the most.

* **[NotesReview](https://ent8r.github.io/NotesReview/)** is a viewer that allows searching and filtering notes. This service is useful for reviewing notes but has limitations when working with large datasets.

* **[OSM Note Viewer](https://antonkhorev.github.io/osm-note-viewer/)** is an excellent note analyzer with many options for filtering and exporting. However, it does not provide any analytical tool to show the status of the notes per user or country.

* **[Notes Map](https://greymiche.lima-city.de/osm_notes/index.html)** is a good try to show a map of notes with a custom icon per type of note. The downside is that the site is only in German. There is not a legend for the icons and the project does not have an issue system.

* **[Notes heatmap](https://notes-heatmap.openstreetmap.fr/)** is a tool to visualize the location of the notes. This helps to show areas that need a lot of work, but that is all.

## Understanding OSM Notes

### What Are Notes?

OpenStreetMap has a feature called notes (<https://wiki.openstreetmap.org/wiki/Notes>), which are used to report, mainly in the field, any discrepancies between what exists in reality and what is mapped. There is also documentation on how to create notes: <https://learnosm.org/en/beginner/notes/>.

Notes can be created anonymously or authenticated in OSM. To resolve them, mappers read them, analyze the text, and according to the note content and what is already on the map, they decide whether or not a change in the map is required.

Many notes may not require changes in the map. Other notes may have false or incomplete information. Therefore, resolving a note is a task that can be easy or complicated.

Also, there are notes that have been created from the computer, for example to report missing elements on the map, such as a river that is not mapped. This type of note can take quite a while to make the change in the map.

### Historical Context

The notes functionality was incorporated into OSM as an extension of the API v0.6 in 2013. Before that, there was a parallel project called OpenStreetBugs that offered similar functionality, but it was integrated into OSM.

### Current Challenges

The current situation is that the activity of resolving notes is not very promoted within the OSM community, and there are very old notes. For some mappers, these notes no longer offer much value and should be closed. On the other hand, some mappers consider that to resolve the notes, the data must be verified; however, this can be an impossible task since there are no alternative data available, and traveling to the location of the notes is not practical.

Due to all this, the communities of different countries and mappers have different points of view and different scopes regarding note resolution. But this work is hardly identifiable since there are few statistics.

## The Need for Better Analytics

### Current Statistics Limitations

The only place that indicates performance regarding note processing is the ResultMaps page by Pascal Neis: <https://resultmaps.neis-one.org/osm-notes> where you can see open notes from all countries and note performance in recent days. On each country's page, you can see the list of the latest 1000 notes, plus a link to the 10,000 open notes. Accessing this page is one of the strategies to resolve notes massively.

On the other hand, in the board section of the same website: <https://osmstats.neis-one.org/?item=boards> you can see the top 100 users who have opened the most notes and who have closed the most (in the Notes section).

Additionally, this website offers a contribution profile in OpenStreetMap, called How Did You Contribute - HDYC, and this profile allows obtaining detailed information about the mapper. This is a page for user AngocA: <https://hdyc.neis-one.org/?AngocA>

There you can identify since when the account was created, how many days they have mapped, performance by country, what types of elements they have created/modified/deleted, the tags used, among other elements. It also has a small section on how many notes they have opened and how many they have closed.

The HDYC page can be considered as the only contribution profile per user, and one of the few per country; however, the note information is very limited.

## Project Goals

This project seeks to offer a profile like HDYC, showing information about activities around notes: opening, commenting, resolution, reopening. This by country (which comes to be each of the OSM communities) and by user. Having a kind of Tiles, like the green GitHub Tiles that show their activity in the last year, important days like the one that closed the most notes, number of notes opened and closed for each year, etc. With this, the mapper can measure their work.

It should also show note performance by hashtags, indicating the date it started, how many notes have been created and closed, and other statistics. Currently, there are no tools that take advantage of note hashtags; however, they have begun to be used more and more.

Another option is to see performance by application and identify how they are being used with respect to notes.

## How This Project Works

As previously said, the purpose of this site is to supply better information about notes in near real-time.

The main challenge is to get the data, which is in separate places:

* **Country and maritime boundaries** are in OpenStreetMap, but the way to obtain them is with Overpass to retrieve all relations that have some specific tags. This involves several requests to Overpass, convert the results, to finally insert them into a Postgres database. Once we have this information in the database, we can query if a specific point (note's location) is inside a country or not.

* **Most recent note changes** can be obtained from OpenStreetMap API calls. However, this service is limited to 10,000 notes, and the current number of notes is above 4 million. Therefore, it is necessary to retrieve the whole note's history in another fashion to start working faster and not stress the API.

* **OSM provides a daily dump** from parts of the database and publishes it in the Planet website. The most well-known dataset is the map data, but for this project, it is necessary to obtain the note dump, which contains the whole history of notes since 2013, only excluding the hidden ones.

In other words, this project uses these three sources of data to keep the database almost in sync with OSM data. This is the most challenging thing about this project, and therefore, this is why it has many objects and prevents duplicates or data loss.

## Data Processing Strategy

### 1. Geographic Data Collection

First, it queries Overpass to get the IDs of the country and maritime boundaries, and then it downloads each of them individually using a FIFO queue system. This queue prevents race conditions when downloading multiple boundaries in parallel, respects Overpass API rate limits, and ensures orderly processing. After downloading, it converts this data into a Postgres geometry and builds the country's table.

### 2. Historical Data Processing

Second, it takes the daily dump from the Planet and builds the base of the note's database. Then, based on the location of the notes, it calculates to which country each note belongs.

### 3. Incremental Synchronization

Third, the program downloads the recent notes from the whole world and populates the tables with this information. Then, it also calculates the country of these new notes. This step is periodic, which means it should be triggered regularly, like every 15 minutes to have recent information. The shorter the time, the more near real-time information this will provide; however, it needs a faster server to process the information.

## Technical Implementation

### Initial Code Structure

With respect to the initial code, it has been written mainly in Bash for interactions with the OSM API to bring new notes, and through the OSM Planet to download the historical notes file.

On the other hand, Overpass has been used to download countries and other regions in the world, and with this information, we can associate a note with a territory.

It is necessary to clarify that the XML document of the Planet for notes does not have the same structure as the XML retrieved through the API. Both XML structures are in the xsd directory to validate them independently.

### Data Warehouse Design

With all this information, a data warehouse has been designed, which is composed of a set of tables in star schema, an ETL that loads the historical data into these tables, using staging tables.

Subsequently, data marts are created for users and for countries, so that the data calculations are already pre-calculated at the time of querying the profiles.

## Services Provided

Once the base information is stored in the database, different services could be provided:

* **WMS Map**: With the location of open and closed notes
* **Data Warehouse**: To perform analytical queries and create user and country profiles about the status of the notes
* **Web Viewer**: Interactive web interface to visualize and explore user and country profiles, statistics, and analytics

As part of the data warehouse, the ETL converts the note's data into a star schema, calculating several facts. Then, the last part is to build a Data Mart with all the necessary values for a user or country profile, reducing the time and impact on the database while executing.

The web viewer provides an intuitive interface to explore these profiles and statistics. For the web viewer implementation, see [OSM-Notes-Viewer](https://github.com/OSMLatam/OSM-Notes-Viewer).

## Technical Decisions

This section documents the key technical decisions made during the development of this project, explaining the rationale behind each choice.

### 1. Language and Technology: Bash

**Why Bash was chosen as the primary language instead of Python or other languages?**

The initial prototype was developed using Linux commands to demonstrate the potential for downloading the Planet dump. This evolved into structured scripts. When presenting the project to the architect Jose Luis Cerón, it was proposed that the API processing part could be done in Python. However, since all the processing was already implemented in Bash, it was decided to continue with Bash for consistency, as the API processing was smaller in scope and didn't require researching how to implement each command in Python.

Additionally, the main developer (AngocA) has strong Bash knowledge, which didn't reduce project complexity. However, this decision had consequences that delayed the project by 2 years:

* **Initial XML Processing**: Initially, XML processing was done with Saxon, which required Java and had restrictions. The free version used too much memory, making it impossible to process the giant Planet XML file.

* **Alternative Attempts**: The project moved to `xmlproc`, which worked partially but began to have memory leaks. `xmlstarlet` was tested, but it uses `xmlproc` underneath, leading to the same problem.

* **Final Solution**: With AI assistance and Cursor IDE support, a solution was developed using AWK - a robust, mature, and effective solution for processing giant files. After this, the project resumed.

**Key Insight**: Bash proved to be a good solution because it's language-independent and can use any tool. The project has tried to minimize dependencies. Python has been avoided, as everything could have been done in Python, but migration would be required. The goal is to release the first version first.

**Why AWK for XML Processing**: AWK was chosen as the final solution for processing XML files because:

* The XML files from Planet and API are very simple in structure and repeat elements many times
* They come formatted in the same consistent way
* This makes it easy to process XML documents as simple text files without validating if they are well-formed documents
* The text is processed according to the structure, which is much faster than full XML parsing
* **Trade-off**: This approach has a risk - if OSM starts generating XML with a different format, AWK could fail. This may become a problem when OSM API evolves to 0.7 or 1.0, or if a new version of Planet is published. However, as long as the format is preserved, it will work. The API 0.6 has been stable for about 12 years, so this risk is acceptable for now.

**Alternatives Considered**: Python, Perl, and Go were not seriously considered, as the only blocker was parsing the Planet XML. However, some aspects like parallelization, flows, and other features could have been abstracted in a language, leveraging the potential of languages or libraries specialized in text processing.

### 2. Architecture and Directory Structure

**Why this directory structure (`bin/`, `sql/`, `tests/`, etc.)?**

The directories were defined to resemble the Linux root directory structure (`etc`, `bin`) and to separate files by type, making them easier to find. This may not be a standard structure and could be refactored in the future, possibly to a Maven-style structure (`main/tests/examples`). This is because `docs` and `tests` were not present from the very beginning.

**Future Consideration**: A refactoring may be done once there is a stable version.

**Relationship between `sql/` and `bin/`**: The `sql/` directory mirrors the structure of `bin/`, where the prefix name matches the scripts in the other directory, maintaining consistency and making it easier to find related SQL scripts for each Bash script.

### 3. Database and Partitions

**Why PostgreSQL with PostGIS?**

PostgreSQL was selected as the database system, with PostGIS extension being crucial for the project. PostGIS provides essential GIS (Geographic Information System) capabilities that are fundamental for validating that a point (note coordinates) is within an area (belongs to a country). This spatial functionality is not available in MySQL, and while commercial databases like Oracle and DB2 offer similar capabilities, PostgreSQL/PostGIS was chosen to keep everything open source, aligning with OSM's open culture and philosophy.

**Why database partitions instead of other strategies?**

Partitions were created so that different threads could work on different parts in independent tables, avoiding lock contention and concurrency problems.

**How partitions are determined**: Partitions are created dynamically based on `MAX_THREADS`, which is calculated as `(number of CPU cores - 2)`. The number of partitions equals `MAX_THREADS`, ensuring that:

* Each parallel processing thread has its own partition table
* All available CPU cores (minus 2) are utilized during parallel processing
* **Load balancing**: When work is divided into many more parts than threads, if one thread finishes its part, it can take the next available task from the queue. This prevents the scenario where one thread finishes quickly while another is still processing a heavy workload, leaving cores idle. For example, in note location validation, old notes from backup already have correct positions (fast processing), while new notes need position calculation (slow processing). If divided only by number of notes, threads processing only old notes finish quickly while threads with only new notes take much longer. By dividing into more parts, threads can balance the workload better by taking tasks from a common queue
* The machine is used to maximum capacity without being overwhelmed

**Alternatives Considered**: Other strategies like sharding, specialized indexes, or separate tables were not evaluated at the time. These may be considered once the system is stable.

### 4. Trade-offs

**What trade-offs were considered during development?**

* **Script Independence**: Scripts were kept independent by functionality. `processPlanet` and `processAPI` have always been independent, even if they do similar things. The problem is that they began to be very long and complex, requiring division into specialized scripts, and eventually library scripts were created that are used by both.

* **Language Choice**: English was used instead of Spanish to have broader adoption when published.

* **Future Considerations**: No other major trade-off decisions have been made, and future refactoring may require taking such decisions.

### 5. Alternatives Evaluated

**What alternatives were evaluated before deciding?**

* **Database**: PostgreSQL with PostGIS was selected for several reasons:
  * It's the same database used by OSM, ensuring compatibility
  * PostGIS provides essential GIS capabilities for spatial operations (validating if a point is within a polygon/area)
  * MySQL does not have equivalent GIS capabilities
  * Commercial databases (Oracle, DB2) have GIS features but were avoided to keep everything open source, aligning with OSM's open culture
  * MySQL could have been option B, but it was not evaluated due to lack of GIS support
  * Non-relational engines were not considered. The main developer sees the project as a traditional high I/O system, where a novel model like JSON in MongoDB may not be necessary at the moment. This may change in the future.

* **Processing Approaches**: The main goal was to have a script that could run on any Linux system without installing many packages, making it immediate.

* **XML Processing**: Multiple XML processing tools were evaluated (Saxon, xmlproc, xmlstarlet) before settling on AWK.

### 6. Design Patterns

**What design patterns are used in the project?**

* **FIFO Queue**: Used for inserting geometries into the database after being downloaded, preventing race conditions and respecting API rate limits.

* **Semaphore Pattern**: Implements a simple semaphore system to limit concurrent downloads to the Overpass API, preventing rate limiting issues and temporary bans. The system:
  * Limits concurrent downloads to a configurable maximum (default: 8 slots, based on Overpass having 2 servers × 4 slots)
  * Uses atomic file operations (`flock` and `mkdir`) to acquire/release download slots
  * Automatically cleans up stale locks from processes that are no longer running
  * Handles HTTP 429 (Too Many Requests) errors with exponential backoff and retry logic
  * Allows the system to interpret temporary bans and wait appropriately before retrying

* **Singleton Pattern**: Ensures only one concurrent execution of `processPlanet`, `processAPI`, `updateCountries`, and `notesCheckVerifier`. This is critical because:
  * `processAPI` and `updateCountries` are the two main entry points of the program
  * These scripts can take more than 15 minutes to complete
  * They are currently configured in crontab to run every 15 minutes
  * Without singleton protection, multiple instances could run simultaneously, causing:
    * Database conflicts and race conditions
    * Duplicate processing of the same data
    * Resource contention and performance degradation
    * Potential data corruption
  * When the execution frequency is reduced (e.g., from 15 minutes to 5 or 2 minutes), this pattern becomes even more critical to prevent overlapping executions

* **Exponential Backoff**: Used in retry logic for API calls and network operations to handle temporary failures gracefully, with increasing delays between retry attempts.

* **Circuit Breaker Pattern**: Implemented in `lib/osm-common/errorHandlingFunctions.sh` to prevent cascading failures. The circuit breaker has three states:
  * **CLOSED**: Normal operation, requests pass through
  * **OPEN**: Too many failures detected, requests are blocked immediately
  * **HALF_OPEN**: Testing if the service has recovered, allowing limited requests
  * Automatically transitions between states based on failure thresholds and timeouts
  * Prevents overwhelming failing services and provides fast failure responses

* **Retry Pattern**: Multiple implementations of retry logic with exponential backoff for:
  * File operations (`__retry_file_operation`)
  * Network operations (`__retry_network_operation`)
  * Database operations (`__retry_database_operation`)
  * API calls (`__retry_osm_api`, `__retry_geoserver_api`)
  * Each retry function handles specific error types and implements appropriate backoff strategies

* **Resource Management/Cleanup Pattern**: Uses `trap` handlers and cleanup functions to ensure resources are properly released:
  * Automatic cleanup of temporary files on script exit
  * Cleanup of download slots in semaphore system
  * Cleanup commands executed on error conditions
  * Respects `CLEAN` flag to allow skipping cleanup in test environments

* **Strategy Pattern**: Used for selecting different algorithms at runtime:
  * **Validation Strategy**: Multiple validation strategies for coordinate checking (grep-based, minimal validation) with fallback mechanisms
  * **Geometry Processing Strategy**: Different strategies for handling problematic geometries (ST_Collect, buffer strategy) with automatic fallback

* **Modular Functions**: The project has sought to reduce coupling and increase script cohesion so that each has a clear purpose.

Other patterns may be implemented implicitly, but these are the main ones documented.

### Additional Technical Details

**Parallel Processing Configuration**:

* The number of parallel threads is determined by `MAX_THREADS = (CPU cores - 2)`
* This ensures the script uses the machine to maximum capacity without overwhelming it
* Using 2 less than the total number of cores prevents system overload while maximizing utilization
* Many long sequential tasks have been divided to parallelize and then consolidate results

**Logging System**:

* Based on log4j standard (Java logging framework)
* The main developer (AngocA) comes from the Java world and was familiar with log4j and logback for their flexibility and modularity
* Searched for Bash equivalents and found one that was close, but AI reimplemented it to be better
* Provides log levels (TRACE, DEBUG, INFO, WARN, ERROR, FATAL) and can send logs to different appenders (not just stdout)

**Data Validation Strategy**:

* **Optional Validations**: The system includes optional validations that can be skipped for faster processing:
  * XML structure validation (`SKIP_XML_VALIDATION` flag)
  * CSV structure validation (`SKIP_CSV_VALIDATION` flag)
  * File existence and readability checks
* **Validation Types Available**:
  * XML structure validation (with XSD schema validation for smaller files)
  * CSV structure and column validation
  * Coordinate validation (lite validation for large files)
  * Enum compatibility validation for database enums
  * Capital location validation for country boundaries
* **Normal Mode**: In normal operation, validations are often skipped to run the process faster
* **Validation Modes**: Different validation strategies based on file size:
  * Very large files (>1000 MB): Structure-only validation
  * Large files (500-1000 MB): Batch validation with fallback
  * Standard files (<500 MB): Full schema validation with timeout protection

### 7. Known Limitations

**What are the known limitations of the current system?**

* **Memory Limitations (Resolved)**: Previously had memory limitations due to Saxon and xsltproc. This has been resolved with the AWK solution.

* **API Rate Limits**: OSM only returns 10,000 notes per API call. To have a good margin of notes, reasonable processing amount, and good time, `processAPI` is called every 15 minutes, with subsequent ETL processing to have near real-time information. When the stable version is ready, this may be reduced to 5 minutes or 2 minutes, but it will require analyzing everything: partitioned tables, validations, etc., and streamlining the process.

* **Future Scalability**: When there are many more notes, problems may be identified. Currently, no other limitations are known.

**Future Improvements**: See [Future Reevaluation Tasks](../ToDo/FUTURE_REEVALUATION.md) for items to be reconsidered once the system is stable.

## Related Documentation

* **System Architecture**: See [Documentation.md](./Documentation.md) for technical implementation details
* **Processing Details**: See [processAPI.md](./processAPI.md) and [processPlanet.md](./processPlanet.md) for specific implementation details
* **Future Reevaluation**: See [ToDo/FUTURE_REEVALUATION.md](../ToDo/FUTURE_REEVALUATION.md) for items to be reconsidered in future versions
