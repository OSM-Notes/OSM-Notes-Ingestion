# OSM-Notes-profile
Mechanism to show a user and country profile about the work on OSM notes.

# Workflow

## Downloading notes

There are two ways to download notes:

* Recent notes from planet (including all notes).
* Near real-time notes from API.

All these options are defined in these two files:

* `processPlanetNotes.sh`
* `processAPINotes.sh`

And everything can be called from `processAPINotes.sh`.

If `processAPINotes.sh` cannot find the base tables, then it will invoke `processPlanetNotes.sh --base` that will create the basic elements on the database:

* Download countries and maritimes areas.

If `processAPINotes.sh` get more than 10 000 notes from an API call, then it will synchronize the database calling `processPlanetNotes.sh`. Then it will:

* Download the notes from planet.
* Remove the duplicates.
* Process the new ones.
* Associate notes with a country or maritime area.

If `processAPINotes.sh` get less than 10 000 notes, it will process them directly.

You can run `processAPINotes.sh` from a crontab each 15 minutes, to process notes almost on real-time.

## Logger

You can export the `LOG_LEVEL` variable, and then call the scripts normally. They will 

```
export LOG_LEVEL=DEBUG
./processAPINotes.sh
```

# Files

* `bash_logger.sh` is a tool for logging with different levels.
* `processAPINotes.sh` is the main script that process the notes with the API.
* `processPlanetNotes.sh` is the base script to process notes from Planet file.
* `processCheckPlanetNotes.sh` is a script that allows to check the notes in
  the database with a new download from planet. This allow to identify
  unprocessed notes and errors in the others scripts.

## Directories

The following directories have their own README file.

* dwh provides the scripts to perform a transformation to a data warehouse and
  show the notes profile.
* wms provides the mechanism to publish a WMS from the notes.

# Insufficient memory resources

If the server where this script runs does not have enough memory (6 GB for Java), then it will not be able to process the Planet notes file, to convert it into a flat file.

To overcome this issue, you can prepare the environment with 3 steps, performed in different computers.

* `processPlanetNotes.sh --base` This creates the basic elements on the db.
* `processPlanetNotes.sh --flatfile` Downloads the Planet notes file and converts it into two CSV flat files. This is the process that should be done in a computer that can reserve 6 GB for Java Saxon.
* `processPlanetNotes.sh --locatenotes` Assign a country to the notes.

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
*/15 * * * * ~/OSM-Notes-profile/processAPINotes.sh
*/15 * * * * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processAPINotes.sh # For detailed execution.
```

# Acknowledgements

Andres Gomez (@AngocA) was the main developer of this idea.
He personally thanks to Jose Luis Ceron Sarria for all his help designing the
architecture, defining the data modeling, and implementing the infrastructure
on the cloud.

Also, thanks to Martin Honnen who helped us improve the XSLT as in this thread:
https://stackoverflow.com/questions/74672609/saxon-out-of-memory-when-processing-openstreetmap-notes-file-from-planet?noredirect=1#comment131821658_74672609

