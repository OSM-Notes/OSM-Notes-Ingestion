# OSM-Notes-profile
Mechanism to show a user and country profile about the work on OSM notes.
Also, it allows publishing a layer with the location of the opened and
closed notes.


# Main functions

These are the main functions of this project.

* Download the notes from the OSM Planet, and then keep data in sync
with the main OSM database via API calls.
This is configured with a scheduler (cron) and it does everything.
* Copy the note's data to another set of tables to allow the
publishing of a WMS layer.
This is configured via triggers on the database.
* Monitor the sync by comparing the Daily Planet with the notes on the
database.
This is optional and can be configured daily with a cron.
* Data warehouse for the notes data.
This is performed with an ETL that takes the note's data and changes the
structure to allow reports, which are used to publish the user and
country profile.
This is configured via a cron.
* View the user or country's profile.


# Workflow

## Configuration file

Before everything, you need to configure the database access and other
properties under the next file:

`etc/properties.sh`

You specify the database name.

## Downloading notes

There are two ways to download notes:

* Recent notes from the planet (including all notes on the daily backup).
* Near real-time notes from API.

All these options are defined in these two files under the `bin` directory:

* `processAPINotes.sh`
* `processPlanetNotes.sh`

And everything can be called from `processAPINotes.sh`.

If `processAPINotes.sh` cannot find the base tables, then it will invoke
`processPlanetNotes.sh --base` that will create the basic elements on the
database and populate it:

* Download countries and maritime areas.

If `processAPINotes.sh` gets more than 10,000 notes from an API call, then it
will synchronize the database calling `processPlanetNotes.sh`. Then it will:

* Download the notes from the planet.
* Remove the duplicates.
* Process the new ones.
* Associate notes with a country or maritime area.

If `processAPINotes.sh` gets less than 10,000 notes, it will process them
directly.

Note: If during the same day, there are more than 10,000 notes between two 
`processAPINotes.sh` call, it will remain unsynchronized until the Planet
is updated. That's why it is recommended to perform frequent API calls.

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

The database has a different set of tables.

* Base tables (notes and note_comments) are the most important holding the
whole history.
* API tables which contain the data for recently modified notes and comments.
The data from these tables are then bulked into base tables.
* Sync tables contain the data from the recent planet download.
* WMS tables in their schema.
Contains the simplified version of the notes with only the location and age.
* DWH are the tables from the data warehouse to perform analysis on the DB.
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
  Planet dump or via API calls.
* `etc` configuration file for many scripts. 
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
* `sql/dwh` includes all scripts to perform the ETL operations on the
  database, including the datamarts' population.
* `sql/monitor` scripts to check the notes database, comparing it with a Planet
  dump.
* `sql/process` has all SQL scripts to load the notes database.
* `sql/wms` provides the mechanism to publish a WMS from the notes.
  This is the only exception to the other files under `/sql`, because this
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

# Install prerequisites on Ubuntu

This is a simplify version of what you need to run on Ubuntu to make it work.

```
sudo apt -y install postgresql
sudo systemctl start postgresql.service
sudo su - postgres
psql << EOF
CREATE USER angoca SUPERUSER;
CREATE DATABASE notes WITH OWNER angoca;
EOF
exit

sudo apt -y install postgis
psql -d notes << EOF
CREATE EXTENSION postgis;
EOF

sudo apt -y install libxml2-utils
sudo apt install -y openjdk-18-jdk

mkdir ~/saxon
cd ~/saxon
wget -O SaxonHE11-4J.zip https://sourceforge.net/projects/saxon/files/Saxon-HE/11/Java/SaxonHE11-4J.zip/download
unzip SaxonHE11-4J.zip
export SAXON_CLASSPATH=~/saxon/

sudo apt -y install npm
sudo npm install -g osmtogeojson

sudo add-apt-repository ppa:ubuntugis/ppa
sudo apt-get -y install gdal-bin
```

However, each script validates the necessary components to work.

# Cron scheduling

To run the notes database synchronization and the data warehouse process, you
could configure the crontab like:

```
# Runs the API extraction each 15 minutes.
*/15 * * * * export SAXON_CLASSPATH=~/saxon/ ; ~/OSM-Notes-profile/bin/process/processAPINotes.sh ; ~/OSM-Notes-profile/bin/dwh/ETL.sh # For normal execution for notes database and data warehouse.
*/15 * * * * export LOG_LEVEL=DEBUG ; export SAXON_CLASSPATH=~/saxon/ ; ~/OSM-Notes-profile/bin/process/processAPINotes.sh ; ~/OSM-Notes-profile/bin/dwh/ETL.sh # For detailed execution.
```

You can also configure the ETL at different times from the notes' processing.
However, the notes' processing should be more frequent than the ETL, otherwise
the ETL does not have data to process.

## Saxon - XML XSLT processor

To run the scripts, it is necessary to have Saxon on the path.
You can also specify the location by defining this environment variable in the
crontab or the command line:

```
export SAXON_CLASSPATH=~/saxon/
```

# Monitoring

To monitor and validate that executions are correct, and the notes processing
does not have errors, periodically you can run the
`processCheckPlanetNotes.sh`.
This will create 2 tables, one for notes and one for comments, with the suffix
`_check`.
By querying the tables with and without the suffix, you can get the
differences; however, it only works around 0h UTC where the planet file is
published. This will compare the differences between the API process and the
Planet.

If you find many differences, especially for comments older than a day, it
means the script failed in the past, and the best is to recreate the database
with the `processPlanetNotes.sh` script, but also create an issue for this
project, providing as much information as possible.

# Remove

```
psql -d notes -f ~/OSM-Notes-profile/sql/dwh/datamartCountries/datamartCountries-dropDatamartObjects.sql ; psql -d notes -f ~/OSM-Notes-profile/sql/dwh/datamartUsers/datamartUsers-dropDatamartObjects.sql ; psql -d notes -f ~/OSM-Notes-profile/sql/dwh/Staging-removeStagingObjects.sql ; psql -d notes -f ~/OSM-Notes-profile/sql/dwh/ETL-removeDWHObjects.sql ; psql -d notes -f ~/OSM-Notes-profile/sql/wms/removeFromDatabase.sql ; psql -d notes -f ~/OSM-Notes-profile/sql/process/processAPINotes-dropApiTables.sql ; psql -d notes -f ~/OSM-Notes-profile/sql/process/processPlanetNotes-dropSyncTables.sql ; psql -d notes -f ~/OSM-Notes-profile/sql/process/processPlanetNotes-dropBaseTables.sql ; psql -d notes -f ~/OSM-Notes-profile/sql/process/processPlanetNotes-dropCountryTables.sql 
```

# Help

You can start looking for help by reading the README.md files.
Also, you run the scripts with -h or --help.
You can even take a look at the code, which is highly documented.
Finally, you can create an issue or contact the author.

# Acknowledgments

Andres Gomez (@AngocA) was the main developer of this idea.
He thanks Jose Luis Ceron Sarria for all his help designing the
architecture, defining the data modeling and implementing the infrastructure
on the cloud.

Also, thanks to Martin Honnen who helped us improve the XSLT as in this thread:
https://stackoverflow.com/questions/74672609/saxon-out-of-memory-when-processing-openstreetmap-notes-file-from-planet?noredirect=1#comment131821658_74672609

