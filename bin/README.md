Under this directory, you can find all shell scripts to run the main
functionalities.

# Directories

* `bin` In this script resides shared functions across many scripts.
* `bin/dwh` Scripts to load and sync the data warehouse.
* `bin/dwh/datamart*` Scripts to group the data by user or by country. 
* `bin/monitor` Script to monitor the daily load compared with the Planet
  notes.
* `bin/process` Main scripts, that load notes from API and Planet.

# Files

* `bin/process/processAPINotes.sh` is the main script that processes the notes
  from the API.
* `bin/process/processPlanetNotes.sh` is the base script to process notes from
  Planet file.
  This script is called internally from `processAPINotes.sh`.

* `bin/functionsProcess.sh` share functions across several scripts.

* `bin/dwh/ETL.sh` loads the data warehouse from the main notes tables.
* `bin/dwh/profiles.sh` shows a user or country profile.

* `bin/monitor/processCheckPlanetNotes.sh` is a script that allows to check the
  notes in the database with a new download from planet.
  This allow to identify unprocessed notes or errors in the other scripts.
* `bin/monitor/notesCheckVerifier.sh` sends an email if there are old
  differences.
  
# Insufficient memory resources

If the server where this script runs does not have enough memory (6 GB for
Java), then it will not be able to process the Planet notes file, to convert it
into a flat file.

To overcome this issue, you can prepare the environment with 3 steps, performed
in different computers with different RAM.

* `processPlanetNotes.sh --base` This creates the basic elements of the
  database.
* `processPlanetNotes.sh --flatfile` Downloads the Planet notes file and
  converts it into two CSV flat files. This is the process that should be done
  in a computer that can reserve 6 GB for Java Saxon.
* `processPlanetNotes.sh --locatenotes` Assign a country to the notes.
