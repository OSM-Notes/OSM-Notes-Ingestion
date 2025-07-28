This is the star-model of the data warehouse.

# Fact table

* fact_id
  * Surrogated id.
* id_note
  * Id of the note from OSM.
* dimesion_id_country
  * Country where the note was created.
* processing_time
  * Timestamp when the row was inserted.
* action_at
  * Timestamp when the note action was performed.
* action_comment
  * Comment action - opened, closed, reopened, commented, hidden.
* action_dimension_id_date
  * Date when the action was performed.
* action_dimension_id_hour_of_week
  * Hour of the day when the action was performed.
* action_dimension_id_user
  * Username who performed the comment action. Creation could be anonymous.
* opened_dimension_id_date
  * Timestamp when the note was created.
* opened_dimension_id_hour_of_week
  * Hour of the day when the note was created.
* opened_dimension_id_user
  * The username of who created the note, it is not anonymous.
* closed_dimension_id_date
  * Timestamp when the note was closed. This value is only filled when the 
    comment is a closing one.
* closed_dimension_id_hour_of_week
  * Hour of the day when the note was closed.
* closed_dimension_id_user
  * Username who closed the node. Only when this
                              comment is a closing one.

# Dimension: users

* dimension_user_id
  * Surrogated id.
* user_id
  * User's id in OSM.
* username
  * Most recent username in OSM.
* modified
  * If the user has performed actions after the last datamart load.

# Dimension: countries

* dimension_country_id
  * Surrogated id.
* country_id
  * Relation id of the country in OSM.
* country_name
  * The name in the local language.
* country_name_es
  * The name in English.
* country_name_en
  * The name is Spanish.
* modified
  * If the country has a modified note after the last datamart load.

# Dimension: days

* dimension_day_id
  * Surrogate id.
* date_id
  * Date.

# Dimension: hours_of_week

* dimension_how_id
  * Surrogate id.
* day_of_week
  * Day of the week.
* hour_of_day
  * Hour of the day.

# Datamart tables

There is also a set of tables for each datamart with the already computed data
for common queries.

# Files

* `ETL.sh` reads the new changes from the notes database and inserts them into
  the facts.
  Also, some dimensions could be changed.
* `profile.sh` generates the profile for a country or a user.
  It is a command line tester for the datamart.

