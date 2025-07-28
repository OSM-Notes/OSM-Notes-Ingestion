# OSM-Notes-profile

Mechanism to show a user and country profile about the work on OSM notes.
Also, it allows publishing a layer with the location of the opened and
closed notes.

# tl;dr - 5 minutes configuration

You just need to download or clone this project in a Linux server and configure
the crontab to invoke the notes pulling.
This example is for polling every 15 minutes:

```
*/15 * * * * ~/OSM-Notes-profile/bin/process/processAPINotes.sh && ~/OSM-Notes-profile/bin/dwh/ETL.sh
```

The configuration file contains the properties needed to configure this tool,
especially the database properties.

# Main functions

These are the main functions of this project.

* Download the notes from the OSM Planet, and then keep data in sync
  with the main OSM database via API calls.
  This is configured with a scheduler (cron) and it does everything.
* Updates the current country and maritime information.
  This should be run once a month.
* Copy the note's data to another set of tables to allow the
  WMS layer publishing.
  This is configured via triggers on the database on the main tables.
* Monitor the sync by comparing the daily Planet dump with the notes on the
  database.
  This is optional and can be configured daily with a cron.
* Data warehouse for the notes data.
  This is performed with an ETL that takes the note's data and changes the
  structure to allow reports, which are used to publish the user and
  country profile.
  This is configured via a cron.
* View the user or country's profile.
  This is a basic version of the report, to test from the command line.

# Timing

The whole process takes several hours, even days to complete before the
profile can be used for any user.

**Notes initial load**

* 5 minutes: Downloading the countries and maritime areas.
  * This process has a pause between calls because the public Overpass turbo is
    restricted by the number of requests per minute.
    If another Overpass instance is used that does not block when many requests,
    the pause could be removed or reduced.
* 1 minute: Download the Planet notes file.
* 4 minutes: Processing XML notes file.
* 12 minutes: Inserting notes into the database.
* 5 minutes: Assign sequence to comments.
* 5 minutes: Load text comments.
* 5 hours: Locating notes in the appropriate country.
  * This DB process is executed in parallel with multiple threads.

**WMS layer**

* 1 minute: creating the objects.

**Notes synchronization**

The synchronization process time depends on the frequency of the calls and the
number of comment actions.
If the notes API call is executed every 15 minutes, the complete process takes
less than 2 minutes to complete.

**ETL and datamarts population**

* 30 hours: Loading the ETL from main tables.
  * This process is parallel according to the number of years since 2013.
    However, not all years have the same number of notes.
* 20 minutes: Preparing the countries' datamart.
* 5 days: Preparing the users' datamart.
  This process is asynchronous, which means each ETL execution processes
  500 users.
  This part analyzes the most active users first; then, all old users that
  have contributed with only one note.
  TODO ETL - parallelize

# Install prerequisites on Ubuntu

This is a simplified version of what you need to execute to run this project on Ubuntu.

```
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

# Tools to process the XML and convert it into CSV.
sudo apt -y install libxml2-utils xsltproc

# Tools to split the XML.
sudo apt install xmlstarlet

# Process parts in paralle.
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

# Cron scheduling

To run the notes database synchronization and the data warehouse process, you
could configure the crontab like (`crontab -e`):

```
# Runs the API extraction each 15 minutes.
# Normal execution for Planet and API process and then data warehouse population.
*/15 * * * * ~/OSM-Notes-profile/bin/process/processAPINotes.sh && ~/OSM-Notes-profile/bin/dwh/ETL.sh

# Download a new Planet version, and checks if the executions have been successful.
# Planet used to be published around 5 am (https://planet.openstreetmap.org/notes/)
0 6 * * * ~/OSM-Notes-profile/bin/process/processPlanetNotes.sh ; ~/OSM-Notes-profile/bin/monitor/notesCheckVerifier.sh

# Runs the boundaries update. Once a month.
0 12 1 * * ~/OSM-Notes-profile/bin/process/updateCountries.sh
```

```
# Runs the API extraction in debug mode, keeping all the generated files.
#*/15 * * * * export LOG_LEVEL=DEBUG ; export CLEAN=false ;~/OSM-Notes-profile/bin/process/processAPINotes.sh && ~/OSM-Notes-profile/bin/dwh/ETL.sh # For detailed execution messages.
```

You can also configure the ETL at different times from the notes' processing.
However, the notes' processing should be more frequent than the ETL, otherwise
the ETL does not have data to process.

# Components description

## Configuration file

Before everything, you need to configure the database access and other
properties under the next file:

`etc/properties.sh`

You specify the database name and the user to access it.

Other properties are related to improving the parallelism to process the note's
location, or to use other URLs for Overpass or the API.

## Downloading notes

There are two ways to download OSM notes:

* Recent notes from the Planet (including all notes on the daily backup).
* Near real-time notes from API.

These two methods are used in this tool to initialize the DB and poll the API
periodically.
The two mechanisms are used, and they are available under the `bin` directory:

* `processAPINotes.sh`
* `processPlanetNotes.sh`

However, to configure from scratch, you just need to call
`processAPINotes.sh`.

If `processAPINotes.sh` cannot find the base tables, then it will invoke
`processPlanetNotes.sh` and `processPlanetNotes.sh --base` that will create the
basic elements on the database and populate it:

* Download countries and maritime areas.
* Download the Planet dump, validate it and convert it CSV to import it into
  the database.
  The conversion from the XML Planet dump to CSV is done with an XLST.
* Get the location of the notes.

If `processAPINotes.sh` gets more than 10,000 notes from an API call, then it
will synchronize the database calling `processPlanetNotes.sh` following this
process:

* Download the notes from the Planet.
* Remove the duplicates from the ones already in the DB.
* Process the new ones.
* Associate new notes with a country or maritime area.

If `processAPINotes.sh` gets less than 10,000 notes, it will process them
directly.

Note: If during the same day, there are more than 10,000 notes between two
`processAPINotes.sh` calls, it will remain unsynchronized until the Planet dump
is updated the next UTC day.
That's why it is recommended to perform frequent API calls.

You can run `processAPINotes.sh` from a crontab every 15 minutes, to process
notes almost in real-time.

## Logger

You can export the `LOG_LEVEL` variable, and then call the scripts normally.

```
export LOG_LEVEL=DEBUG
./processAPINotes.sh
```

The levels are (case-sensitive):

* TRACE
* DEBUG
* INFO
* WARN
* ERROR
* FATAL

## Database

These are the table types on the database:

* Base tables (notes and note_comments) are the most important holding the
  whole history.
  They don't belong to a specific schema.
* API tables which contain the data for recently modified notes and comments.
  The data from these tables are then bulked into base tables.
  They don't belong to a specific schema, but a suffix.
* Sync tables contain the data from the recent planet download.
  They don't belong to a specific schema, but a suffix.
* WMS tables which are used to publish the WMS layer.
  Their schema is `wms`.
They contain a simplified version of the notes with only the location and
  age.
* `dwh` are the tables from the data warehouse to perform analysis on the DB.
  They are divided into 2:
The star schema is composed of the fact and dimensions tables.
  * The datamarts which are precomputed views.
* Check tables are used for monitoring to compare the notes on the previous day
  between the normal behavior with API and the notes on the last day of the
  Planet.

## Directories

Some directories have their own README file to explain their content.
These files include details about how to run or troubleshoot the scripts.

* `bin` contains all executable scripts, and this directory contains the common
  functions invoked from other scripts.
* `bin/dwh` provides the scripts to perform a transformation to a data
  warehouse and show the notes profile.
  It also includes the datamart load and a profile tester.
* `bin/monitor` contains a set of scripts to monitor the notes database to
  validate it has the same data as the planet, and eventually send an email
  message with the differences.
* `bin/process` has the main script to download the notes database, with the
  Planet dump and via API calls.
* `etc` configuration file for many scripts.
* `json` JSON files for schema and testing.
* `lib` libraries used in the project.
  Currently only a modified version of bash logger.
* `overpass` queries to download data with Overpass for the countries and
  maritime boundaries.
* `sld` files to format the WMS layer on the GeoServer.
* `sql` contains most of the SQL statements to be executed in Postgres.
  It follows the same directory structure from `/bin` where the prefix name is
  the same as the scripts on the other directory.
  This directory also contains a script to keep a copy of the locations of the
  notes in case of a re-execution of the whole Planet process.
  And also the script to remove everything related to this project from the DB.
* `sql/dwh` includes all scripts to perform the ETL operations on the
  database, including the datamarts' population.
* `sql/monitor` scripts to check the notes database, comparing it with a Planet
  dump.
* `sql/process` has all SQL scripts to load the notes database.
* `sql/wms` provides the mechanism to publish a WMS from the notes.
  This is the only exception to the other files under `sql` because this
  feature is supported only on SQL scripts; there is no bash script for this.
  this is the only location of the files related to the WMS layer publishing.
* `test` set of scripts to perform tests.
  This is not part of a Unit Test set.
* `xsd` contains the structure of the XML documents to be retrieved - XML
  Schema.
  This helps validate the structure of the documents, preventing errors
  during the import from the Planet dump and API calls.
* `xslt` contains all the XML transformations for the data retrieved from the
  Planet dump and API calls.
  They are used from `processAPINotes.sh` and `processPlanetNotes.sh`.

## Monitoring

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

## WMS layer

This is the way to create the objects for the WMS layer.
More information is in the `README.md` file under the `sql/wms` directory.

### Automated Installation (Recommended)

Use the WMS manager script for easy installation and management:

```bash
# Install WMS components
~/OSM-Notes-profile/bin/wms/wmsManager.sh install

# Check installation status
~/OSM-Notes-profile/bin/wms/wmsManager.sh status

# Remove WMS components
~/OSM-Notes-profile/bin/wms/wmsManager.sh deinstall

# Show help
~/OSM-Notes-profile/bin/wms/wmsManager.sh help
```

### Manual Installation

For manual installation, execute the SQL directly:

```bash
psql -d notes -v ON_ERROR_STOP=1 -f ~/OSM-Notes-profile/sql/wms/prepareDatabase.sql
```

# Dependencies and libraries

These are the external dependencies to make it work.

* OSM Planet dump, which creates a daily file with all notes and comments.
  The file is an XML and it weighs several hundreds of MB of compressed data.
* Overpass to download the current boundaries of the countries and maritimes
  areas.
* OSM API which is used to get the most recent notes and comments.
  The current API version supported is 0.6.
* The whole process relies on a PostgreSQL database.
  It uses intensive SQL action to have a good performance when processing the
  data.

The external dependencies are almost fixed, however, they could be changed from
the properties file.

These are external libraries:

* bash_logger, which is a tool to write log4j-like messages in Bash.
  This tool is included as part of the project.
* Bash 4 or higher, because the main code is developed in the scripting
  language.
* Linux and its commands, because it is developed in Bash, which uses a lot
  of command line instructions.

# Remove

You can use the following script to remove components from this tool.
This is useful if you have to recreate some parts, but the rest is working fine.

```bash
# ETL part.
psql -d notes -f ~/OSM-Notes-profile/sql/dwh/datamartCountries/datamartCountries_dropDatamartObjects.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/dwh/datamartUsers/datamartUsers_dropDatamartObjects.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/dwh/Staging_removeStagingObjects.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/dwh/ETL_12_removeDatamartObjects.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/dwh/ETL_13_removeDWHObjects.sql ;

# WMS part.
psql -d notes -f ~/OSM-Notes-profile/sql/wms/removeFromDatabase.sql ;

# Base part.
psql -d notes -f ~/OSM-Notes-profile/sql/monitor/processCheckPlanetNotes_11_dropCheckTables.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/process/processAPINotes_11_dropApiTables.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/functionsProcess_12_dropGenericObjects.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/process/processPlanetNotes_11_dropSyncTables.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/process/processPlanetNotes_13_dropBaseTables.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/process/processPlanetNotes_14_dropCountryTables.sql ;

rm -rf /tmp/process*
```

You can also use the ```cleanAll.sh``` script under the ```test``` directory.

# Help

You can start looking for help by reading the README.md files.
Also, you run the scripts with -h or --help.
There are few Github wiki pages with interesting information.
You can even take a look at the code, which is highly documented.
Finally, you can create an issue or contact the author.

# Acknowledgments

Andres Gomez (@AngocA) was the main developer of this idea.
He thanks Jose Luis Ceron Sarria for all his help designing the
architecture, defining the data modeling and implementing the infrastructure
on the cloud.
