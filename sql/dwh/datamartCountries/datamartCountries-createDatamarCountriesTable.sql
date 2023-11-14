-- Creates datamart for countries.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-10

CREATE TABLE IF NOT EXISTS dwh.datamartCountries (
 -- Static values (country name could change)
 dimension_country_id INTEGER, -- The dimension id country.
 country_id INTEGER,
 country_name VARCHAR(100),
 country_name_es VARCHAR(100),
 country_name_en VARCHAR(100),
 date_starting_creating_notes DATE, -- Oldest opened note.
 date_starting_solving_notes DATE, -- Oldest closed note.
 first_open_note_id INTEGER, -- Oldest.
 first_commented_note_id INTEGER,
 first_closed_note_id INTEGER,
 first_reopened_note_id INTEGER,

 -- Dynamic values
 last_year_activity TEXT, -- Most recent note action. TODO
 lastest_open_note_id INTEGER, -- Newest.
 lastest_commented_note_id INTEGER,
 lastest_closed_note_id INTEGER,
 lastest_reopened_note_id INTEGER,
 date_most_open DATE, -- Day when most notes were opened.
 date_most_open_qty SMALLINT,
 date_most_closed DATE, -- Day when most notes were closed
 date_most_closed_qty SMALLINT,
 hashtags JSON, -- List of used hashtag.
 users_open_notes JSON, -- List of countries where opening notes.
 users_solving_notes JSON, -- List of countries where closing notes.
 working_hours_opening JSON, -- Hours when creates notes.
 working_hours_commenting JSON, -- Hours when comments notes.
 working_hours_closing JSON, -- Hours when closes notes.
 history_whole_open INTEGER, -- Qty opened notes.
 history_whole_commented INTEGER, -- Qty commented notes.
 history_whole_closed INTEGER, -- Qty closed notes.
 history_whole_closed_with_comment INTEGER, -- Qty closed notes with comments.
 history_whole_reopened INTEGER, -- Qty reopened notes.
 history_year_open INTEGER, -- Qty in the current year.
 history_year_commented INTEGER,
 history_year_closed INTEGER,
 history_year_closed_with_comment INTEGER,
 history_year_reopened INTEGER,
 history_month_open INTEGER, -- Qty in the current month.
 history_month_commented INTEGER,
 history_month_closed INTEGER,
 history_month_closed_with_comment INTEGER,
 history_month_reopened INTEGER,
 history_day_open INTEGER, -- Qty in the current day.
 history_day_commented INTEGER,
 history_day_closed INTEGER,
 history_day_closed_with_comment INTEGER,
 history_day_reopened INTEGER,
 history_2013_open INTEGER, -- Qty in 2013
 history_2013_commented INTEGER,
 history_2013_closed INTEGER,
 history_2013_closed_with_comment INTEGER,
 history_2013_reopened INTEGER
);

-- Primary keys.
ALTER TABLE dwh.datamartCountries
 ADD CONSTRAINT pk_datamartCountries
 PRIMARY KEY (dimension_country_id);
