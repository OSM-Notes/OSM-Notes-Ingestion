CREATE TABLE IF NOT EXISTS dwh.datamartUsers (
 user_id INTEGER NOT NULL,
 username VARCHAR(256),
 date_starting_creating_notes DATE,
 date_starting_solving_notes DATE,
 countries_open_notes VARCHAR(1024),
 countries_solving_notes VARCHAR(1024),
 contributor_type_id INTEGER,
 last_year_activity CHAR(366),
 working_hours_opening CHAR(7),
 working_hours_commenting CHAR(7),
 working_hours_closing char(7),
 first_open_note_id INTEGER,
 first_commented_note_id INTEGER,
 first_closed_note_id INTEGER,
 first_reopened_note_id INTEGER,
 last_open_note_id INTEGER,
 last_commented_note_id INTEGER,
 last_closed_note_id INTEGER,
 last_reopened_note_id INTEGER,
 history_whole_open INTEGER,
 history_whole_commented INTEGER,
 history_whole_closed INTEGER,
 history_whole_closed_with_comment INTEGER,
 history_whole_reopened INTEGER,
 history_year_open INTEGER,
 history_year_commented INTEGER,
 history_year_closed INTEGER,
 history_year_closed_with_comment INTEGER,
 history_year_reopened INTEGER,
 history_month_open INTEGER,
 history_month_commented INTEGER,
 history_month_closed INTEGER,
 history_month_closed_with_comment INTEGER,
 history_month_reopened INTEGER,
 history_day_open INTEGER,
 history_day_commented INTEGER,
 history_day_closed INTEGER,
 history_day_closed_with_comment INTEGER,
 history_day_reopened INTEGER,
 history_2013_open INTEGER,
 history_2013_commented INTEGER,
 history_2013_closed INTEGER,
 history_2013_closed_with_comment INTEGER,
 history_2013_reopened INTEGER,
 history_2014_open INTEGER,
 history_2014_commented INTEGER,
 history_2014_closed INTEGER,
 history_2014_closed_with_comment INTEGER,
 history_2014_reopened INTEGER,
 history_2015_open INTEGER,
 history_2015_commented INTEGER,
 history_2015_closed INTEGER,
 history_2015_closed_with_comment INTEGER,
 history_2015_reopened INTEGER,
 history_2016_open INTEGER,
 history_2016_commented INTEGER,
 history_2016_closed INTEGER,
 history_2016_closed_with_comment INTEGER,
 history_2016_reopened INTEGER,
 history_2017_open INTEGER,
 history_2017_commented INTEGER,
 history_2017_closed INTEGER,
 history_2017_closed_with_comment INTEGER,
 history_2017_reopened INTEGER,
 history_2018_open INTEGER,
 history_2018_commented INTEGER,
 history_2018_closed INTEGER,
 history_2018_closed_with_comment INTEGER,
 history_2018_reopened INTEGER,
 history_2019_open INTEGER,
 history_2019_commented INTEGER,
 history_2019_closed INTEGER,
 history_2019_closed_with_comment INTEGER,
 history_2019_reopened INTEGER,
 history_2020_open INTEGER,
 history_2020_commented INTEGER,
 history_2020_closed INTEGER,
 history_2020_closed_with_comment INTEGER,
 history_2020_reopened INTEGER,
 history_2021_open INTEGER,
 history_2021_commented INTEGER,
 history_2021_closed INTEGER,
 history_2021_closed_with_comment INTEGER,
 history_2021_reopened INTEGER,
 history_2022_open INTEGER,
 history_2022_commented INTEGER,
 history_2022_closed INTEGER,
 history_2022_closed_with_comment INTEGER,
 history_2022_reopened INTEGER,
 history_2023_open INTEGER,
 history_2023_commented INTEGER,
 history_2023_closed INTEGER,
 history_2023_closed_with_comment INTEGER,
 history_2023_reopened INTEGER,
 date_most_open DATE,
 date_most_closed DATE,
 hashtags VARCHAR(1024)
);

--TODO Each year, 5 new columns should be added

-- TODO populate badges

CREATE TABLE IF NOT EXISTS dwh.badges (
 badge_id INTEGER NOT NULL,
 badge_name VARCHAR(64)
};

CREATE TABLE IF NOT EXISTS dwh.badges_per_users (
 id_user INTEGER NOT NULL,
 id_badge INTEGER NOT NULL,
 date_awarded DATE NOT NULL
};

CREATE TABLE IF NOT EXISTS dwh.contributor_types (
 contributor_type_id INTEGER NOT NULL,
 contributor_type_name VARCHAR(64) NOT NULL
};

CREATE OR REPLACE FUNCTION get_last_year_actions (
 user_id INTEGER NOT NULL
) RETURN CHAR(365)
 LANGUAGE plpgsql
 AS $func$
  DECLARE
   id_country INTEGER;
  BEGIN
   id_country := -1;
   RETURN id_country;
  END
 $func$
;

