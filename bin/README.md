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
