# OSM-Notes-profile
Mechanism to show a user and country profile about the work on OSM notes.

# Workflow

## Downloading notes

There are three ways to download notes:

* All notes from planet.
* Recent notes from planet.
* Near real-time notes from API.

All three options are defined in these two files:

* `processPlanetNotes.sh`
* `processAPINotes.sh`

And everything can be called from `processAPINotes.sh`.

If `processAPINotes.sh` cannot find the base tables, then it will can `processPlanetNotes.sh --base` that will create everything on the database:

* Download countries and maritimes areas.
* Download planet notes file, and process them, associating them with a country or maritime area.

If `processAPINotes.sh` get more than 10 000 notes from an API call, then it will synchronize the database calling `processPlanetNotes.sh`. Then it will:

* Download the notes from planet.
* Remove the duplicates.
* Process the new ones.

If `processAPINotes.sh` get less than 10 000 notes, it will process them directly.

You can run `processAPINotes.sh` from a crontab each 15 minutes, to process notes almost on real-time.

### Logger

You can export the `LOG_LEVEL` variable, and then call the scripts normally. They will 

```
export LOG_LEVEL=DEBUG
./processAPINotes.sh
```

# Files

* `bash_logger.sh` is a tool for logging with different levels.
* `processAPINotes.sh` is the main script that process the notes with the API.
* `processPlanetNotes.sh` is the base script to process notes from Planet file.
