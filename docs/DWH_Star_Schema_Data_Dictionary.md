# DWH Star Schema Data Dictionary

Version: 2025-08-08

This document provides a tabular data dictionary for the star schema used
in the data warehouse. It covers the fact table and all dimensions,
including data types, nullability, defaults, keys, and functional
descriptions.

Conventions:

- Types are PostgreSQL types.
- PK: Primary Key, FK: Foreign Key.
- N: NOT NULL, Y: NULL allowed.

## Table: dwh.facts

Central fact table with one row per note action (open, comment, reopen,
close, hide).

| Column                               | Type             | Null | Default                | Key | Description |
|--------------------------------------|------------------|------|------------------------|-----|-------------|
| fact_id                              | SERIAL           | N    | auto                   | PK  | Surrogate key |
| id_note                              | INTEGER          | N    |                        |     | OSM note id |
| sequence_action                      | INTEGER          | Y    |                        |     | Creation sequence per action |
| dimension_id_country                 | INTEGER          | N    |                        | FK  | Country dimension key |
| processing_time                      | TIMESTAMP        | N    | CURRENT_TIMESTAMP      |     | Insert timestamp |
| action_at                            | TIMESTAMP        | N    |                        |     | Action timestamp |
| action_comment                       | note_event_enum  | N    |                        |     | Action type: opened/closed/... |
| action_dimension_id_date             | INTEGER          | N    |                        | FK  | Date dimension key of action |
| action_dimension_id_hour_of_week     | SMALLINT         | N    |                        | FK  | Hour-of-week dimension key of action |
| action_dimension_id_user             | INTEGER          | Y    |                        | FK  | User dimension key of action |
| opened_dimension_id_date             | INTEGER          | N    |                        | FK  | Date dimension key when note was opened |
| opened_dimension_id_hour_of_week     | SMALLINT         | N    |                        | FK  | Hour-of-week key when note was opened |
| opened_dimension_id_user             | INTEGER          | Y    |                        | FK  | User dimension key who opened |
| closed_dimension_id_date             | INTEGER          | Y    |                        | FK  | Date dimension key when closed |
| closed_dimension_id_hour_of_week     | SMALLINT         | Y    |                        | FK  | Hour-of-week key when closed |
| closed_dimension_id_user             | INTEGER          | Y    |                        | FK  | User dimension key who closed |
| dimension_application_creation       | INTEGER          | Y    |                        | FK  | Application dimension key used to open |
| recent_opened_dimension_id_date      | INTEGER          | N    |                        | FK  | Most recent open/reopen date key |
| days_to_resolution                   | INTEGER          | Y    |                        |     | Days from first open to most recent close |
| days_to_resolution_active            | INTEGER          | Y    |                        |     | Total days in open status across reopens |
| days_to_resolution_from_reopen       | INTEGER          | Y    |                        |     | Days from last reopen to most recent close |
| hashtag_1                            | INTEGER          | Y    |                        | FK  | Hashtag dimension key (first) |
| hashtag_2                            | INTEGER          | Y    |                        | FK  | Hashtag dimension key (second) |
| hashtag_3                            | INTEGER          | Y    |                        | FK  | Hashtag dimension key (third) |
| hashtag_4                            | INTEGER          | Y    |                        | FK  | Hashtag dimension key (fourth) |
| hashtag_5                            | INTEGER          | Y    |                        | FK  | Hashtag dimension key (fifth) |
| hashtag_number                       | INTEGER          | Y    |                        |     | Total number of hashtags detected |

Notes:

- FKs: country → `dwh.dimension_countries.dimension_country_id`,
  date/hour/user → corresponding dimensions, application →
  `dwh.dimension_applications.dimension_application_id`, hashtags →
  `dwh.dimension_hashtags.dimension_hashtag_id`.
- `recent_opened_dimension_id_date` is enforced NOT NULL after unify step.
- Resolution day metrics are maintained by trigger on insert of closing
  actions.

## Table: dwh.dimension_users

| Column            | Type          | Null | Default | Key | Description |
|-------------------|---------------|------|---------|-----|-------------|
| dimension_user_id | SERIAL        | N    | auto    | PK  | Surrogate key |
| user_id           | INTEGER       | N    |         |     | OSM user id |
| username          | VARCHAR(256)  | Y    |         |     | Most recent username |
| modified          | BOOLEAN       | Y    |         |     | Flag for datamart updates |

## Table: dwh.dimension_regions

| Column               | Type         | Null | Default | Key | Description |
|----------------------|--------------|------|---------|-----|-------------|
| dimension_region_id  | SERIAL       | N    | auto    | PK  | Surrogate key |
| region_name_es       | VARCHAR(60)  | Y    |         |     | Name in Spanish |
| region_name_en       | VARCHAR(60)  | Y    |         |     | Name in English |

## Table: dwh.dimension_countries

| Column               | Type          | Null | Default | Key | Description |
|----------------------|---------------|------|---------|-----|-------------|
| dimension_country_id | SERIAL        | N    | auto    | PK  | Surrogate key |
| country_id           | INTEGER       | N    |         |     | OSM relation id |
| country_name         | VARCHAR(100)  | Y    |         |     | Local name |
| country_name_es      | VARCHAR(100)  | Y    |         |     | Spanish name |
| country_name_en      | VARCHAR(100)  | Y    |         |     | English name |
| region_id            | INTEGER       | Y    |         | FK  | Region key → `dimension_regions` |
| modified             | BOOLEAN       | Y    |         |     | Flag for datamart updates |

## Table: dwh.dimension_days

| Column           | Type     | Null | Default | Key | Description |
|------------------|----------|------|---------|-----|-------------|
| dimension_day_id | SERIAL   | N    | auto    | PK  | Surrogate key |
| date_id          | DATE     | Y    |         |     | Full date |
| year             | SMALLINT | Y    |         |     | Year component |
| month            | SMALLINT | Y    |         |     | Month component |
| day              | SMALLINT | Y    |         |     | Day component |
| iso_year         | SMALLINT | Y    |         |     | ISO year |
| iso_week         | SMALLINT | Y    |         |     | ISO week (1..53) |
| day_of_year      | SMALLINT | Y    |         |     | Day of year (1..366) |
| quarter          | SMALLINT | Y    |         |     | Quarter (1..4) |
| month_name       | VARCHAR(16) | Y |         |     | Month name (en) |
| day_name         | VARCHAR(16) | Y |         |     | Day name (en, ISO) |
| is_weekend       | BOOLEAN  | Y    |         |     | Weekend flag (ISO) |
| is_month_end     | BOOLEAN  | Y    |         |     | Month-end flag |
| is_quarter_end   | BOOLEAN  | Y    |         |     | Quarter-end flag |
| is_year_end      | BOOLEAN  | Y    |         |     | Year-end flag |

## Table: dwh.dimension_time_of_week

| Column            | Type     | Null | Default | Key | Description |
|-------------------|----------|------|---------|-----|-------------|
| dimension_tow_id  | SMALLINT | Y    |         | PK  | Encodes day-of-week and hour |
| day_of_week       | SMALLINT | Y    |         |     | 1..7 (ISO) |
| hour_of_day       | SMALLINT | Y    |         |     | 0..23 |
| hour_of_week      | SMALLINT | Y    |         |     | 0..167 |
| period_of_day     | VARCHAR(16) | Y |         |     | Night/Morning/Afternoon/Evening |

## Table: dwh.dimension_applications

| Column                   | Type         | Null | Default | Key | Description |
|--------------------------|--------------|------|---------|-----|-------------|
| dimension_application_id | SERIAL       | N    | auto    | PK  | Surrogate key |
| application_name         | VARCHAR(64)  | N    |         |     | Application name |
| pattern                  | VARCHAR(64)  | Y    |         |     | Pattern used to detect the app in text |
| pattern_type             | VARCHAR(16)  | Y    |         |     | SIMILAR/LIKE/REGEXP |
| platform                 | VARCHAR(16)  | Y    |         |     | Optional platform |
| vendor                   | VARCHAR(32)  | Y    |         |     | Vendor/author |
| category                 | VARCHAR(32)  | Y    |         |     | Category/type |
| active                   | BOOLEAN      | Y    |         |     | Active flag |

## Table: dwh.dimension_hashtags

| Column               | Type | Null | Default | Key | Description |
|----------------------|------|------|---------|-----|-------------|
| dimension_hashtag_id | SERIAL | N  | auto    | PK  | Surrogate key |
| description          | TEXT | Y   |         |     | Hashtag text |

## Operational table: dwh.properties

## Table: dwh.dimension_timezones

| Column               | Type        | Null | Default | Key | Description |
|----------------------|-------------|------|---------|-----|-------------|
| dimension_timezone_id| SERIAL      | N    | auto    | PK  | Surrogate key |
| tz_name              | VARCHAR(64) | N    |         |     | IANA timezone name or UTC±N band |
| utc_offset_minutes   | SMALLINT    | Y    |         |     | UTC offset in minutes |

## Table: dwh.dimension_seasons

| Column               | Type        | Null | Default | Key | Description |
|----------------------|-------------|------|---------|-----|-------------|
| dimension_season_id  | SMALLINT    | N    |         | PK  | Season id |
| season_name_en       | VARCHAR(16) | Y    |         |     | Season name (en) |
| season_name_es       | VARCHAR(16) | Y    |         |     | Season name (es) |

## Table: dwh.dimension_continents

| Column                 | Type         | Null | Default | Key | Description |
|------------------------|--------------|------|---------|-----|-------------|
| dimension_continent_id | SERIAL       | N    | auto    | PK  | Surrogate key |
| continent_name_es      | VARCHAR(32)  | Y    |         |     | Continent (es) |
| continent_name_en      | VARCHAR(32)  | Y    |         |     | Continent (en) |

## Updates to existing tables

### dwh.dimension_countries (added columns)

| Column      | Type         | Description |
|-------------|--------------|-------------|
| iso_alpha2  | VARCHAR(2)   | ISO 3166-1 alpha-2 |
| iso_alpha3  | VARCHAR(3)   | ISO 3166-1 alpha-3 |

### dwh.dimension_users (SCD2 columns)

| Column     | Type       | Description |
|------------|------------|-------------|
| valid_from | TIMESTAMP  | Validity start |
| valid_to   | TIMESTAMP  | Validity end |
| is_current | BOOLEAN    | Current row flag |

### dwh.facts (added columns)

| Column                              | Type      | Description |
|-------------------------------------|-----------|-------------|
| action_timezone_id                  | INTEGER   | FK to timezone |
| local_action_dimension_id_date      | INTEGER   | Local date id |
| local_action_dimension_id_hour_of_week | SMALLINT | Local time-of-week id |
| action_dimension_id_season          | SMALLINT  | Season id |
| dimension_application_version       | INTEGER   | FK to app version |

## Bridge table: dwh.fact_hashtags
## Table: dwh.dimension_application_versions

| Column                          | Type        | Null | Default | Key | Description |
|---------------------------------|-------------|------|---------|-----|-------------|
| dimension_application_version_id| SERIAL      | N    | auto    | PK  | Surrogate key |
| dimension_application_id        | INTEGER     | N    |         | FK  | Application |
| version                         | VARCHAR(32) | N    |         |     | Version string |

| Column              | Type     | Description |
|---------------------|----------|-------------|
| fact_id             | INTEGER  | FK to facts |
| dimension_hashtag_id| INTEGER  | FK to hashtags |
| position            | SMALLINT | Positional order in text |

Used internally by ETL orchestration.

| Column | Type        | Null | Default | Key | Description |
|--------|-------------|------|---------|-----|-------------|
| key    | VARCHAR(16) | Y    |         |     | Property name |
| value  | VARCHAR(26) | Y    |         |     | Property value |
