-- Creates country tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
CREATE TABLE countries (
 country_id INTEGER NOT NULL,
 country_name VARCHAR(100) NOT NULL,
 country_name_es VARCHAR(100),
 country_name_en VARCHAR(100),
 geom GEOMETRY NOT NULL,
 americas INTEGER,
 europe INTEGER,
 russia_middle_east INTEGER,
 asia_oceania INTEGER
);

ALTER TABLE countries
 ADD CONSTRAINT pk_countries
 PRIMARY KEY (country_id);

CREATE TABLE tries (
 area VARCHAR(20),
 iter INTEGER,
 id_note INTEGER,
 id_country INTEGER
);
