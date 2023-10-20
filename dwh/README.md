This is the star-model of the data warehouse.

# Fact table

* id                     # Surrogated.
* id_note                # Id of the note from OSM.
* created_at             # Timestamp when the note was created.
* created_id_user        # Username who created the note, it not annonyous.
* number_open_notes_user # Number of notes created by this user, historically.
* closed_at              # Timestamp when the note was closed. This value is only filled when the comment is a closing one.
* closed_id_user         # Username who closed the node. Only when this comment is a closing one.
* number_closed_notes_user # Number of notes closed by this user, historically.
* id_country             # Country where the note was created.
* number_notes_country     # Number of notes created in this country.
* action_comment         # Comment action - opened, closed, reopenned, commented, hidden.
* action_id_user         # Username who performed the comment action. Creation could be annonymous.
* action_at              # Timestamp when the action was performed.
* action_id_date         # Date when the action was performed.

# Dimension: country


# Dimesion: time


# Dimension: users


# Staging tables
These are the necessary files to process the note and show a profile for users
and countries.

# Files

* `ETL.sh`
* `alterObjects.sql`
* `createObjects.sql`
* `datamartUsers`
* `emptyTables.sql`
* `populateTables.sql`
* `profile.sh`
* `removeObjects.sql`

