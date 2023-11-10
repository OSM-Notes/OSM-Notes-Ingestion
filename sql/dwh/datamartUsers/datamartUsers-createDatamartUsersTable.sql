-- Creates data warehouse relations.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-09

CREATE TABLE IF NOT EXISTS dwh.datamartUsers (
 -- Static values (username could change)
 dimension_user_id INTEGER, -- The dimension id user.
 user_id INTEGER, -- The OSM id user.
 username VARCHAR,
 date_starting_creating_notes DATE, -- Oldest opened note.
 date_starting_solving_notes DATE, -- Oldest closed note.
 first_open_note_id INTEGER, -- Oldest.
 first_commented_note_id INTEGER,
 first_closed_note_id INTEGER,
 first_reopened_note_id INTEGER,

 -- Dynamic values
 id_contributor_type SMALLINT, -- Note contributor type.
 last_year_activity TEXT, -- Most recent note action.
 lastest_open_note_id INTEGER, -- Newest.
 lastest_commented_note_id INTEGER,
 lastest_closed_note_id INTEGER,
 lastest_reopened_note_id INTEGER,
 date_most_open DATE, -- Day when the user opened the most notes.
 date_most_open_qty SMALLINT,
 date_most_closed DATE, -- Day when the user closed notes the most.
 date_most_closed_qty SMALLINT,
 hashtags JSON, -- List of used hashtag.
 countries_open_notes JSON, -- List of countries where opening notes.
 countries_solving_notes JSON, -- List of countries where closing notes.
 working_hours_opening JSON, -- Hours when the user creates notes.
 working_hours_commenting JSON, -- Hours when the user comments notes.
 working_hours_closing JSON, -- Hours when the user closes notes.
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

CREATE TABLE IF NOT EXISTS dwh.badges (
 badge_id SERIAL,
 badge_name VARCHAR(64)
);

CREATE TABLE IF NOT EXISTS dwh.badges_per_users (
 id_user INTEGER NOT NULL,
 id_badge INTEGER NOT NULL,
 date_awarded DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS dwh.contributor_types (
 contributor_type_id SERIAL,
 contributor_type_name VARCHAR(64) NOT NULL
);

-- Primary keys.
ALTER TABLE dwh.datamartUsers
 ADD CONSTRAINT pk_datamartUsers
 PRIMARY KEY (dimension_user_id);

ALTER TABLE dwh.badges
 ADD CONSTRAINT pk_badges
 PRIMARY KEY (badge_id);

ALTER TABLE dwh.badges_per_users
 ADD CONSTRAINT pk_badge_users
 PRIMARY KEY (id_user, id_badge);

ALTER TABLE dwh.contributor_types
 ADD CONSTRAINT pk_contributor_types
 PRIMARY KEY (contributor_type_id);

-- Foreign keys.
ALTER TABLE dwh.datamartUsers
 ADD CONSTRAINT fk_contributor_type
 FOREIGN KEY (id_contributor_type)
 REFERENCES dwh.contributor_types (contributor_type_id);

ALTER TABLE dwh.badges_per_users
 ADD CONSTRAINT fk_b_p_u_id_badge
 FOREIGN KEY (id_badge)
 REFERENCES dwh.badges (badge_id);

ALTER TABLE dwh.badges_per_users
 ADD CONSTRAINT fk_b_p_u_id_user
 FOREIGN KEY (id_user)
 REFERENCES dwh.datamartUsers (dimension_user_id);

-- Insert values
-- TODO populate badges.
INSERT INTO dwh.badges (badge_name) VALUES
 ('Test');

-- TODO Populate contributor types.
INSERT INTO dwh.contributor_types (contributor_type_name) VALUES
 ('Notero');
