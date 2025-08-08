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

## Table: dwh.dimension_hours_of_week

| Column            | Type     | Null | Default | Key | Description |
|-------------------|----------|------|---------|-----|-------------|
| dimension_how_id  | SMALLINT | Y    |         | PK  | Encodes day-of-week and hour |
| day_of_week       | SMALLINT | Y    |         |     | 1..7 |
| hour_of_day       | SMALLINT | Y    |         |     | 1..24 |

## Table: dwh.dimension_applications

| Column                   | Type         | Null | Default | Key | Description |
|--------------------------|--------------|------|---------|-----|-------------|
| dimension_application_id | SERIAL       | N    | auto    | PK  | Surrogate key |
| application_name         | VARCHAR(64)  | N    |         |     | Application name |
| pattern                  | VARCHAR(64)  | Y    |         |     | Pattern used to detect the app in text |
| platform                 | VARCHAR(16)  | Y    |         |     | Optional platform |

## Table: dwh.dimension_hashtags

| Column               | Type | Null | Default | Key | Description |
|----------------------|------|------|---------|-----|-------------|
| dimension_hashtag_id | SERIAL | N  | auto    | PK  | Surrogate key |
| description          | TEXT | Y   |         |     | Hashtag text |

## Operational table: dwh.properties

Used internally by ETL orchestration.

| Column | Type        | Null | Default | Key | Description |
|--------|-------------|------|---------|-----|-------------|
| key    | VARCHAR(16) | Y    |         |     | Property name |
| value  | VARCHAR(26) | Y    |         |     | Property value |
