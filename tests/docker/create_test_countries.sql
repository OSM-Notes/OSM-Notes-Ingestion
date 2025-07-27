-- Simplified countries table and get_country function for testing
-- Version: 2025-07-27

-- Create simplified countries table
CREATE TABLE IF NOT EXISTS countries (
  country_id INTEGER PRIMARY KEY,
  name VARCHAR(100),
  americas BOOLEAN DEFAULT FALSE,
  europe BOOLEAN DEFAULT FALSE,
  russia_middle_east BOOLEAN DEFAULT FALSE,
  asia_oceania BOOLEAN DEFAULT FALSE
);

-- Insert some test countries
INSERT INTO countries (country_id, name, americas, europe, russia_middle_east, asia_oceania) VALUES
  (1, 'United States', TRUE, FALSE, FALSE, FALSE),
  (2, 'United Kingdom', FALSE, TRUE, FALSE, FALSE),
  (3, 'Germany', FALSE, TRUE, FALSE, FALSE),
  (4, 'Japan', FALSE, FALSE, FALSE, TRUE),
  (5, 'Australia', FALSE, FALSE, FALSE, TRUE);

-- Create tries table for logging
CREATE TABLE IF NOT EXISTS tries (
  area VARCHAR(20),
  iter INTEGER,
  id_note INTEGER,
  id_country INTEGER
);

-- Create simplified get_country function for testing
CREATE OR REPLACE FUNCTION get_country (
  lon DECIMAL,
  lat DECIMAL,
  id_note INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql
AS $func$
DECLARE
  m_id_country INTEGER;
  m_area VARCHAR(20);
BEGIN
  m_id_country := 1; -- Default to US for testing
  
  -- Simple logic based on longitude for testing
  IF (lon < -30) THEN
    m_area := 'Americas';
    m_id_country := 1; -- US
  ELSIF (lon < 25) THEN
    m_area := 'Europe/Africa';
    m_id_country := 2; -- UK
  ELSIF (lon < 65) THEN
    m_area := 'Russia/Middle east';
    m_id_country := 3; -- Germany
  ELSE
    m_area := 'Asia/Oceania';
    m_id_country := 4; -- Japan
  END IF;
  
  INSERT INTO tries VALUES (m_area, 1, id_note, m_id_country);
  RETURN m_id_country;
END
$func$;

COMMENT ON FUNCTION get_country IS
  'Simplified version for testing - returns country based on longitude'; 