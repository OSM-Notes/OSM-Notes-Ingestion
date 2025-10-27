# OSM-Notes-Ingestion

**Data Ingestion and WMS for OpenStreetMap Notes**

This repository handles downloading, processing, and publishing OSM notes data.
It provides:

- Notes ingestion from OSM Planet and API
- Real-time synchronization with the main OSM database
- WMS (Web Map Service) layer publication
- Data monitoring and validation

> **Note:** The analytics, data warehouse, and ETL components have been moved to
> [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

## tl;dr - 5 minutes configuration

You just need to download or clone this project in a Linux server and configure
the crontab to invoke the notes pulling.
This example is for polling every 15 minutes:

```text
*/15 * * * * ~/OSM-Notes-Ingestion/bin/process/processAPINotes.sh
```

The configuration file contains the properties needed to configure this tool,
especially the database properties.

## Main functions

These are the main functions of this project:

- **Notes Ingestion**: Download notes from the OSM Planet and keep data in sync
  with the main OSM database via API calls.
  This is configured with a scheduler (cron) and it does everything.
- **Country Boundaries**: Updates the current country and maritime information.
  This should be run once a month.
- **WMS Layer**: Copy the note's data to another set of tables to allow the
  WMS layer publishing.
  This is configured via triggers on the database on the main tables.
- **Data Monitoring**: Monitor the sync by comparing the daily Planet dump with the notes on the
  database.
  This is optional and can be configured daily with a cron.

For **analytics, data warehouse, ETL, and profile generation**, see the
[OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics) repository.

## Shared Functions (Git Submodule)

This project uses a Git submodule for shared code (`lib/osm-common/`):

- **Common Functions** (`commonFunctions.sh`): Core utility functions
- **Validation Functions** (`validationFunctions.sh`): Data validation
- **Error Handling** (`errorHandlingFunctions.sh`): Error handling and recovery
- **Logger** (`bash_logger.sh`): Logging library (log4j-style)

These functions are shared with [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics)
via the [OSM-Notes-Common](https://github.com/angoca/OSM-Notes-Common) submodule.

### Cloning with Submodules

```bash
# Clone with submodules (recommended)
git clone --recurse-submodules https://github.com/angoca/OSM-Notes-Ingestion.git

# Or initialize after cloning
git clone https://github.com/angoca/OSM-Notes-Ingestion.git
cd OSM-Notes-Ingestion
git submodule update --init --recursive
```

### Troubleshooting: Submodule Issues

If you encounter the error `/lib/osm-common/commonFunctions.sh: No such file or directory`, the submódule has not been initialized. To fix:

```bash
# Initialize and update submodules
git submodule update --init --recursive

# Verify submodule exists
ls -la lib/osm-common/commonFunctions.sh

# If still having issues, re-initialize completely
git submodule deinit -f lib/osm-common
git submodule update --init --recursive
```

To check submodule status:

```bash
git submodule status
```

If the submodule is not properly initialized, you'll see a `-` prefix in the status output.

#### Authentication Issues

If you encounter authentication errors:

**For SSH (recommended):**

```bash
# Test SSH connection to GitHub
ssh -T git@github.com

# If connection fails, set up SSH keys:
# 1. Generate SSH key: ssh-keygen -t ed25519
# 2. Add public key to GitHub: cat ~/.ssh/id_ed25519.pub
# 3. Add key at: https://github.com/settings/keys
```

**For HTTPS:**

```bash
# Use GitHub Personal Access Token instead of password
# Create token at: https://github.com/settings/tokens
# Then clone: git clone https://YOUR_TOKEN@github.com/...
```

See [Submodule Troubleshooting Guide](./docs/Submodule_Troubleshooting.md) for detailed instructions.

## Timing

The whole process takes several hours, even days to complete before the
profile can be used for any user.

**Notes initial load**

- 3 minutes: Downloading the countries and maritime areas.
  - This process has a pause between calls because the public Overpass turbo is
    restricted by the number of requests per minute.
    If another Overpass instance is used that does not block when many requests,
    the pause could be removed or reduced.
- 1 minute: Download the Planet notes file.
- 5 minutes: Processing XML notes file.
- 15 minutes: Inserting notes into the database.
- 8 minutes: Processing and consolidating notes from partitions.
- 3 hours: Locating notes in the appropriate country (parallel processing).
  - This DB process is executed in parallel with multiple threads.

**WMS layer**

- 1 minute: creating the objects.

**Notes synchronization**

The synchronization process time depends on the frequency of the calls and the
number of comment actions.
If the notes API call is executed every 15 minutes, the complete process takes
less than 2 minutes to complete.

## Install prerequisites on Ubuntu

This is a simplified version of what you need to execute to run this project on Ubuntu.

```text
# Configure the PostgreSQL database.
sudo apt -y install postgresql
sudo systemctl start postgresql.service
sudo su - postgres
psql << EOF
CREATE USER notes SUPERUSER;
CREATE DATABASE notes WITH OWNER notes;
EOF
exit

# PostGIS extension for Postgres.
sudo apt -y install postgis
psql -d notes << EOF
CREATE EXTENSION postgis;
EOF

# Generalized Search Tree extension for Postgres.
psql -d notes << EOF
CREATE EXTENSION btree_gist
EOF

# Tool to download in parallel threads.
sudo apt install -y aria2

# Tools to validate XML (optional, only if SKIP_XML_VALIDATION=false).
sudo apt -y install libxml2-utils

# Process parts in parallel.
sudo apt install parallel

# Tools to process geometries.
sudo apt -y install npm
sudo npm install -g osmtogeojson

# JSON validator.
sudo npm install ajv
sudo npm install -g ajv-cli

# Mail sender for notifications.
sudo apt install -y mutt

sudo add-apt-repository ppa:ubuntugis/ppa
sudo apt-get -y install gdal-bin

```

If you do not configure the prerequisites, each script validates the necessary
components to work.

## Cron scheduling

To run the notes database synchronization, configure the crontab like (`crontab -e`):

```text
# Runs the API extraction each 15 minutes.
*/15 * * * * ~/OSM-Notes-Ingestion/bin/process/processAPINotes.sh

# Download a new Planet version, and checks if the executions have been successful.
# Planet used to be published around 5 am (https://planet.openstreetmap.org/notes/)
0 6 * * * ~/OSM-Notes-Ingestion/bin/process/processPlanetNotes.sh ; ~/OSM-Notes-Ingestion/bin/monitor/notesCheckVerifier.sh

# Runs the boundaries update. Once a month.
0 12 1 * * ~/OSM-Notes-Ingestion/bin/process/updateCountries.sh
```

For **ETL and Analytics scheduling**, see the [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics) repository.

## Components description

### Configuration file

Before everything, you need to configure the database access and other
properties under the next file:

`etc/properties.sh`

You specify the database name and the user to access it.

Other properties are related to improving the parallelism to process the note's
location, or to use other URLs for Overpass or the API.

### Downloading notes

There are two ways to download OSM notes:

- Recent notes from the Planet (including all notes on the daily backup).
- Near real-time notes from API.

These two methods are used in this tool to initialize the DB and poll the API
periodically.
The two mechanisms are used, and they are available under the `bin` directory:

- `processAPINotes.sh`
- `processPlanetNotes.sh`

However, to configure from scratch, you just need to call
`processAPINotes.sh`.

If `processAPINotes.sh` cannot find the base tables, then it will invoke
`processPlanetNotes.sh` and `processPlanetNotes.sh --base` that will create the
basic elements on the database and populate it:

- Download countries and maritime areas.
- Download the Planet dump, validate it and convert it CSV to import it into
  the database.
  The conversion from the XML Planet dump to CSV is done with an XLST.
- Get the location of the notes.

If `processAPINotes.sh` gets more than 10,000 notes from an API call, then it
will synchronize the database calling `processPlanetNotes.sh` following this
process:

- Download the notes from the Planet.
- Remove the duplicates from the ones already in the DB.
- Process the new ones.
- Associate new notes with a country or maritime area.

If `processAPINotes.sh` gets less than 10,000 notes, it will process them
directly.

Note: If during the same day, there are more than 10,000 notes between two
`processAPINotes.sh` calls, it will remain unsynchronized until the Planet dump
is updated the next UTC day.
That's why it is recommended to perform frequent API calls.

You can run `processAPINotes.sh` from a crontab every 15 minutes, to process
notes almost in real-time.

### Logger

You can export the `LOG_LEVEL` variable, and then call the scripts normally.

```text
export LOG_LEVEL=DEBUG
./processAPINotes.sh
```

The levels are (case-sensitive):

- TRACE
- DEBUG
- INFO
- WARN
- ERROR
- FATAL

### Database

These are the table types on the database:

- Base tables (notes and note_comments) are the most important holding the
  whole history.
  They don't belong to a specific schema.
- API tables which contain the data for recently modified notes and comments.
  The data from these tables are then bulked into base tables.
  They don't belong to a specific schema, but a suffix.
- Sync tables contain the data from the recent planet download.
  They don't belong to a specific schema, but a suffix.
- WMS tables which are used to publish the WMS layer.
  Their schema is `wms`.
They contain a simplified version of the notes with only the location and
  age.
- `dwh` schema contains the data warehouse tables (managed by OSM-Notes-Analytics).
  See [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics) for details.
- Check tables are used for monitoring to compare the notes on the previous day
  between the normal behavior with API and the notes on the last day of the
  Planet.

### Directories

Some directories have their own README file to explain their content.
These files include details about how to run or troubleshoot the scripts.

- `bin` contains all executable scripts for ingestion and WMS.
- `bin/monitor` contains scripts to monitor the notes database to
  validate it has the same data as the planet, and send email
  messages with differences.
- `bin/process` has the main scripts to download the notes database, with the
  Planet dump and via API calls.
- `bin/wms` contains scripts for WMS (Web Map Service) layer management.
- `etc` configuration file for many scripts.
- `json` JSON files for schema and testing.
- `lib` libraries used in the project.
  Currently only a modified version of bash logger.
- `overpass` queries to download data with Overpass for the countries and
  maritime boundaries.
- `sld` files to format the WMS layer on the GeoServer.
- `sql` contains most of the SQL statements to be executed in Postgres.
  It follows the same directory structure from `/bin` where the prefix name is
  the same as the scripts on the other directory.
  This directory also contains a script to keep a copy of the locations of the
  notes in case of a re-execution of the whole Planet process.
  And also the script to remove everything related to this project from the DB.
- `sql/monitor` scripts to check the notes database, comparing it with a Planet
  dump.
- `sql/process` has all SQL scripts to load the notes database.
- `sql/wms` provides the mechanism to publish a WMS from the notes.
  This is the only exception to the other files under `sql` because this
  feature is supported only on SQL scripts; there is no bash script for this.
  This is the only location of the files related to the WMS layer publishing.
- **For DWH/ETL SQL scripts**, see [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).
- `test` set of scripts to perform tests.
  This is not part of a Unit Test set.
- `xsd` contains the structure of the XML documents to be retrieved - XML
  Schema.
  This helps validate the structure of the documents, preventing errors
  during the import from the Planet dump and API calls.
- `awk` contains all the AWK extraction scripts for the data retrieved from
  the Planet dump and API calls.
  They convert XML to CSV efficiently with minimal dependencies.

### Monitoring

Periodically, you can run the following script to monitor and validate that
executions are correct, and also that notes processing have not had errors:
`processCheckPlanetNotes.sh`.

This script will create 2 tables, one for notes and one for comments, with the
 suffix `_check`.
By querying the tables with and without the suffix, you can get the
differences;
however, it better works around 6h UTC when the OSM Planet file is published.
This will compare the differences between the API process and the Planet data.

If you find many differences, especially for comments older than one day, it
means the script failed in the past, and the best is to recreate the database
with the `processPlanetNotes.sh` script.
It is also recommended to create an issue in this GitHub repository, providing
as much information as possible.

### WMS layer

This is the way to create the objects for the WMS layer.
More information is in the `README.md` file under the `sql/wms` directory.

#### Automated Installation (Recommended)

Use the WMS manager script for easy installation and management:

```bash
# Install WMS components
~/OSM-Notes-Ingestion/bin/wms/wmsManager.sh install

# Check installation status
~/OSM-Notes-Ingestion/bin/wms/wmsManager.sh status

# Remove WMS components
~/OSM-Notes-Ingestion/bin/wms/wmsManager.sh deinstall

# Show help
~/OSM-Notes-Ingestion/bin/wms/wmsManager.sh help
```

#### Manual Installation

For manual installation, execute the SQL directly:

```bash
psql -d notes -v ON_ERROR_STOP=1 -f ~/OSM-Notes-Ingestion/sql/wms/prepareDatabase.sql
```

## Dependencies and libraries

These are the external dependencies to make it work.

- OSM Planet dump, which creates a daily file with all notes and comments.
  The file is an XML and it weighs several hundreds of MB of compressed data.
- Overpass to download the current boundaries of the countries and maritimes
  areas.
- OSM API which is used to get the most recent notes and comments.
  The current API version supported is 0.6.
- The whole process relies on a PostgreSQL database.
  It uses intensive SQL action to have a good performance when processing the
  data.

The external dependencies are almost fixed, however, they could be changed from
the properties file.

These are external libraries:

- bash_logger, which is a tool to write log4j-like messages in Bash.
  This tool is included as part of the project.
- Bash 4 or higher, because the main code is developed in the scripting
  language.
- Linux and its commands, because it is developed in Bash, which uses a lot
  of command line instructions.

## Remove

You can use the following script to remove components from this tool.
This is useful if you have to recreate some parts, but the rest is working fine.

```bash
# Remove all components from the database (uses default from properties: osm_notes)
~/OSM-Notes-Ingestion/bin/cleanupAll.sh

# Clean only partitions
~/OSM-Notes-Ingestion/bin/cleanupAll.sh -p

# Change database in etc/properties.sh (DBNAME variable)
# Then run cleanup for that database
~/OSM-Notes-Ingestion/bin/cleanupAll.sh
```

**Note:** This script handles all components including partition tables, dependencies, and temporary files automatically. Manual cleanup is not recommended as it may leave partition tables or dependencies unresolved.

## Help

You can start looking for help by reading the README.md files.
Also, you run the scripts with -h or --help.
There are few Github wiki pages with interesting information.
You can even take a look at the code, which is highly documented.
Finally, you can create an issue or contact the author.

## Testing

The project includes comprehensive testing infrastructure with **101 test suite
files** (~1,000+ individual tests) covering all ingestion system components.

### Quick Testing

```bash
# Run all tests (recommended)
./tests/run_all_tests.sh

# Run simple tests (no sudo required)
./tests/run_tests_simple.sh

# Run integration tests
./tests/run_integration_tests.sh

# Run quality tests
./tests/run_quality_tests.sh

# Run logging pattern validation tests
./tests/run_logging_validation_tests.sh

# Run sequential tests by level
./tests/run_tests_sequential.sh quick  # 15-20 min
```

### Test Categories

- **Unit Tests**: 86 bash suites + 6 SQL suites
- **Integration Tests**: 8 end-to-end workflow suites
- **Parallel Processing**: 1 comprehensive suite with 21 tests
- **Validation Tests**: Data validation, XML processing, error handling
- **Performance Tests**: Parallel processing, edge cases, optimization
- **Quality Tests**: Code quality, conventions, formatting
- **Logging Pattern Tests**: Logging pattern validation and compliance
- **WMS Tests**: Web Map Service integration and configuration

### Test Coverage

- ✅ **Data Processing**: XML/CSV processing, transformations
- ✅ **System Integration**: Database operations, API integration, WMS services
- ✅ **Quality Assurance**: Code quality, error handling, edge cases
- ✅ **Infrastructure**: Monitoring, configuration, tools and utilities
- ✅ **Logging Patterns**: Logging pattern validation and compliance across all scripts

### Documentation

- [Testing Suites Reference](./docs/Testing_Suites_Reference.md) - Complete list of all testing suites
- [Testing Guide](./docs/Testing_Guide.md) - Testing guidelines and workflows
- [Testing Workflows Overview](./docs/Testing_Workflows_Overview.md) - CI/CD testing workflows

For detailed testing information, see the [Testing Suites Reference](./docs/Testing_Suites_Reference.md) documentation.

## Database Configuration

The project uses PostgreSQL for data storage. Before running the scripts, ensure proper database configuration:

### Development Environment Setup

1. **Install PostgreSQL:**

   ```bash
   sudo apt-get update && sudo apt-get install postgresql postgresql-contrib
   ```

2. **Configure authentication (choose one option):**

   **Option A: Trust authentication (recommended for development)**

   ```bash
   sudo nano /etc/postgresql/15/main/pg_hba.conf
   # Change 'peer' to 'trust' for local connections
   sudo systemctl restart postgresql
   ```

   **Option B: Password authentication**

   ```bash
   echo "localhost:5432:osm_notes:myuser:your_password" > ~/.pgpass
   chmod 600 ~/.pgpass
   ```

3. **Test connection:**

   ```bash
   psql -U myuser -d osm_notes -c "SELECT 1;"
   ```

### Database Configuration

The project is configured to use:

- **Database:** `osm_notes`
- **User:** `myuser`
- **Authentication:** peer (uses system user)

Configuration is stored in `etc/properties.sh`.

For troubleshooting, check the PostgreSQL logs and ensure proper authentication configuration.

### Local Development Setup

To avoid accidentally committing local configuration changes, you can configure Git to ignore changes to the properties files:

```bash
# Tell Git to ignore changes to properties files (local development only)
git update-index --assume-unchanged etc/properties.sh
git update-index --assume-unchanged etc/osm-notes-processing.properties
git update-index --assume-unchanged etc/wms.properties.sh

# Verify that the files are now ignored
git ls-files -v | grep '^[[:lower:]]'

# To re-enable tracking (if needed)
git update-index --no-assume-unchanged etc/properties.sh
git update-index --no-assume-unchanged etc/osm-notes-processing.properties
git update-index --no-assume-unchanged etc/wms.properties.sh
```

**Note:** This is useful for development environments where you need to customize database settings, user names, or WMS settings without affecting the repository.

## Acknowledgments

Andres Gomez (@AngocA) was the main developer of this idea.
He thanks Jose Luis Ceron Sarria for all his help designing the
architecture, defining the data modeling and implementing the infrastructure
on the cloud.
