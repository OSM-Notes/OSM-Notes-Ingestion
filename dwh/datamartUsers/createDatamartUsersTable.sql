CREATE TABLE IF NOT EXISTS dwh.datamartUsers (
 user_id INTEGER NOT NULL,
 username VARCHAR(256),
 date_starting_creating_notes DATE,
 date_starting_solving_notes DATE,
 countries_open_notes VARCHAR(256),
 countries_solving_notes VARCHAR(256),
 last_year_activity CHAR(366)
);

