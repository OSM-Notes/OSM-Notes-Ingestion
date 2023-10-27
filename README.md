# OSM-Notes-profile
Mechanism to show a user and country profile about the work on OSM notes.
Also, it allows to publish a layer with the location of the opened and
closed notes.


# Main functions

These are the main functions of this project.

* Download the notes from the OSM Planet, and then keep data in sync
with the main OSM database via API calls.
This is configured with a scheduler (cron) and it does everything.
* Copy the note's data to another set to tables to allow the
publishing of a WMS layer.
This is configured via triggers on the database.
* Monitor the sync by comparing the daily Planet with the notes on the
database.
This is optional and can be configured with a cron.
* Data warehouse for the notes data.
This is performed with an ETL that takes the note's data and changes the
structure to allow reports, which are used to publish the user and
country profile.
This is configured via a cron.
* Test the user or country's profile.


# Workflow

## Configuration file

Before everything, you need to configure the database access and other
properties under the next file:

`etc/properties.sh`

## Downloading notes

There are two ways to download notes:

* Recent notes from planet (including all notes).
* Near real-time notes from API.

All these options are defined in these two files under `bin` directory:

* `processPlanetNotes.sh`
* `processAPINotes.sh`

And everything can be called from `processAPINotes.sh`.

If `processAPINotes.sh` cannot find the base tables, then it will invoke
`processPlanetNotes.sh --base` that will create the basic elements on the
database:

* Download countries and maritimes areas.

If `processAPINotes.sh` get more than 10 000 notes from an API call, then it
will synchronize the database calling `processPlanetNotes.sh`. Then it will:

* Download the notes from planet.
* Remove the duplicates.
* Process the new ones.
* Associate notes with a country or maritime area.

If `processAPINotes.sh` get less than 10 000 notes, it will process them
directly.

You can run `processAPINotes.sh` from a crontab each 15 minutes, to process
notes almost on real-time.

## Logger

You can export the `LOG_LEVEL` variable, and then call the scripts normally.

```
export LOG_LEVEL=DEBUG
./processAPINotes.sh
```

The levels are (case sensitive):

* TRACE
* DEBUG
* INFO
* WARN
* ERROR
* FATAL

## Database

The database has different set of tables.

* Base tables (notes and note_comments) that are the most important with the
whole history.
* API tables which contain the data for recently modified notes and comments.
The data from these tables are then bulked into base tables.
* Sync tables contain the data from the recent planet.
* WMS tables in its own schema.
Contains the simplified version of the notes with only the location and age.
* DWH are the tables from the data warehouse to perform analyzed on the DB.
* Check tables are used for monitoring to compare the notes on the previous day
between the normal behaviour with API and the notes on the last day of the
Planet.

## Directories

The following directories have their own README file.
These files include details how to run or troubleshot the scripts.

* `bin` explains all scripts under that directory to call the main functions.
* `bin/dwh` provides the scripts to perform a transformation to a data warehouse and
  show the notes profile.
* `etc` configuration file for many script. 
* `lib` libraries used in the project.
Currently onely bash logger.
* `overpass` queries to download data with Overpass to the countries and
maritimes boundaries. 
* `sld` files to format the WMS layer on the GeoServer. 
* `sql` contains most of the SQL statement to be executed in Postgres.
It follows the same directory structure from `/bin` where the prefix name is
the same of the scripts on the other directory.
This directory also contains a script to keep a copy of the locations of the
notes in case of a re-execution of the whole Planet process.
* `sql/wms` provides the mechanism to publish a WMS from the notes.
This is the only exception to the other files under `/sql`.
In fact, this is the only location of the files related to the WMS layer
publishing.
* `test` set of scripts to perform test.
This is not part of a Unit Test set. 
* `xsd` contains the structure of the XML documents to be retrieved - XML
Schema.
This helps to validate the structure of the documents, preventing errors
during the import.
* `xslt` contains all the XML transformation for the data retrieved from the
API. 
They are used from `processAPINotes.sh` and `processPlanetNotes.sh`.

# Install prerequisites on Ubuntu

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

# Cron scheduling

```
# Runs the API extraction each 15 minutes.
*/15 * * * * ~/OSM-Notes-profile/processAPINotes.sh # For normal execution.
*/15 * * * * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processAPINotes.sh # For detailed execution.
```

# Saxon - XML XSLT processor

To run the scripts, it is necessary to have Saxon on the path.
You can also specify the location by defining this in the crons or the command line:

```
export SAXON_CLASSPATH=~/saxon/
```

# Monitoring

To monitor and valida the executions are correct, periodically you can run the
`processCheckPlanetNotes.sh`. This will create 2 tables, one for notes and one
for comments, with the suffix `_check`.
By querying the tables with and without the suffix, you can get the
differences; however it only works around 0h where the planet file is
published. This will compare the differences between the API process and the
Planet.

If you find many differences, specially very old ones, it means the script
failed in the past, and the best is to recreate the database with the
`processPlanetNotes.sh` script, but also create an issue for the project,
providing as much informaction as possible.

# Help

You can start looking for help by reading the README.md files.
Also, you run the scripts with -h or --help.
You can even take a look at the code, which is highly documented.
Finally, you can create an issue or contact the author.

# Acknowledgements

Andres Gomez (@AngocA) was the main developer of this idea.
He personally thanks to Jose Luis Ceron Sarria for all his help designing the
architecture, defining the data modeling, and implementing the infrastructure
on the cloud.

Also, thanks to Martin Honnen who helped us improve the XSLT as in this thread:
https://stackoverflow.com/questions/74672609/saxon-out-of-memory-when-processing-openstreetmap-notes-file-from-planet?noredirect=1#comment131821658_74672609

