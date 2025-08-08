# DWH Star Schema ERD

Version: 2025-08-08

This document shows the entity–relationship diagram (ERD) of the star schema.
The central fact table is `dwh.facts`, connected to its dimensions.

```mermaid
erDiagram
  DWH_FACTS {
    SERIAL fact_id PK
    INTEGER id_note
    INTEGER sequence_action
    INTEGER dimension_id_country FK
    TIMESTAMP processing_time
    TIMESTAMP action_at
    note_event_enum action_comment
    INTEGER action_dimension_id_date FK
    SMALLINT action_dimension_id_hour_of_week FK
    INTEGER action_dimension_id_user FK
    INTEGER opened_dimension_id_date FK
    SMALLINT opened_dimension_id_hour_of_week FK
    INTEGER opened_dimension_id_user FK
    INTEGER closed_dimension_id_date FK
    SMALLINT closed_dimension_id_hour_of_week FK
    INTEGER closed_dimension_id_user FK
    INTEGER dimension_application_creation FK
    INTEGER recent_opened_dimension_id_date FK
    INTEGER days_to_resolution
    INTEGER days_to_resolution_active
    INTEGER days_to_resolution_from_reopen
    INTEGER hashtag_1 FK
    INTEGER hashtag_2 FK
    INTEGER hashtag_3 FK
    INTEGER hashtag_4 FK
    INTEGER hashtag_5 FK
    INTEGER hashtag_number
    INTEGER action_timezone_id FK
    INTEGER local_action_dimension_id_date FK
    SMALLINT local_action_dimension_id_hour_of_week FK
    SMALLINT action_dimension_id_season FK
  }

  DWH_DIMENSION_USERS {
    SERIAL dimension_user_id PK
    INTEGER user_id
    VARCHAR username
    BOOLEAN modified
  }

  DWH_DIMENSION_COUNTRIES {
    SERIAL dimension_country_id PK
    INTEGER country_id
    VARCHAR country_name
    VARCHAR country_name_es
    VARCHAR country_name_en
    INTEGER region_id FK
    BOOLEAN modified
  }

  DWH_DIMENSION_REGIONS {
    SERIAL dimension_region_id PK
    VARCHAR region_name_es
    VARCHAR region_name_en
  }

  DWH_DIMENSION_DAYS {
    SERIAL dimension_day_id PK
    DATE date_id
    SMALLINT year
    SMALLINT month
    SMALLINT day
  }

  DWH_DIMENSION_TIME_OF_WEEK {
    SMALLINT dimension_tow_id PK
    SMALLINT day_of_week
    SMALLINT hour_of_day
    SMALLINT hour_of_week
    VARCHAR period_of_day
  }

  DWH_DIMENSION_APPLICATIONS {
    SERIAL dimension_application_id PK
    VARCHAR application_name
    VARCHAR pattern
    VARCHAR platform
  }
  DWH_DIMENSION_APPLICATION_VERSIONS {
    SERIAL dimension_application_version_id PK
    INTEGER dimension_application_id FK
    VARCHAR version
  }

  DWH_DIMENSION_HASHTAGS {
    SERIAL dimension_hashtag_id PK
    TEXT description
  }

  DWH_DIMENSION_TIMEZONES {
    SERIAL dimension_timezone_id PK
    VARCHAR tz_name
    SMALLINT utc_offset_minutes
  }

  DWH_DIMENSION_SEASONS {
    SMALLINT dimension_season_id PK
    VARCHAR season_name_en
    VARCHAR season_name_es
  }

  DWH_DIMENSION_CONTINENTS {
    SERIAL dimension_continent_id PK
    VARCHAR continent_name_es
    VARCHAR continent_name_en
  }

  %% Relationships
  DWH_FACTS }o--|| DWH_DIMENSION_COUNTRIES : "dimension_id_country"
  DWH_FACTS }o--|| DWH_DIMENSION_DAYS : "action_dimension_id_date"
  DWH_FACTS }o--|| DWH_DIMENSION_TIME_OF_WEEK : "action_dimension_id_hour_of_week"
  DWH_FACTS }o--|| DWH_DIMENSION_USERS : "action_dimension_id_user"
  DWH_FACTS }o--|| DWH_DIMENSION_DAYS : "opened_dimension_id_date"
  DWH_FACTS }o--|| DWH_DIMENSION_TIME_OF_WEEK : "opened_dimension_id_hour_of_week"
  DWH_FACTS }o--|| DWH_DIMENSION_USERS : "opened_dimension_id_user"
  DWH_FACTS }o--|| DWH_DIMENSION_DAYS : "closed_dimension_id_date"
  DWH_FACTS }o--|| DWH_DIMENSION_TIME_OF_WEEK : "closed_dimension_id_hour_of_week"
  DWH_FACTS }o--|| DWH_DIMENSION_USERS : "closed_dimension_id_user"
  DWH_FACTS }o--|| DWH_DIMENSION_APPLICATIONS : "dimension_application_creation"
  DWH_FACTS }o--|| DWH_DIMENSION_APPLICATION_VERSIONS : "dimension_application_version"
  DWH_FACTS }o--|| DWH_DIMENSION_DAYS : "recent_opened_dimension_id_date"
  DWH_FACTS }o--|| DWH_DIMENSION_HASHTAGS : "hashtag_1..hashtag_5"
  DWH_FACTS }o--|| DWH_DIMENSION_TIMEZONES : "action_timezone_id"
  DWH_FACTS }o--|| DWH_DIMENSION_DAYS : "local_action_dimension_id_date"
  DWH_FACTS }o--|| DWH_DIMENSION_TIME_OF_WEEK : "local_action_dimension_id_hour_of_week"
  DWH_FACTS }o--|| DWH_DIMENSION_SEASONS : "action_dimension_id_season"

  DWH_DIMENSION_COUNTRIES }o--|| DWH_DIMENSION_REGIONS : "region_id"
  DWH_DIMENSION_REGIONS }o--|| DWH_DIMENSION_CONTINENTS : "continent_id"
```

Notes:

- The ERD shows logical relationships aligned with foreign keys defined in
  the SQL DDL. The hashtags relationship is a shorthand for up to five
  optional links to `dimension_hashtags`.
- Cardinalities:
  - Facts to dimensions are many-to-one.
  - Countries to regions are many-to-one.
