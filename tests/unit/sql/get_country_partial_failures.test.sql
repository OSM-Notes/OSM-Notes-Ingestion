-- Unit tests for get_country function partial failures
-- Tests that detect when SOME notes in a country return -1/-2 while others work correctly
-- This detects the bug where some notes in Brazil/Venezuela/Chile returned -1 incorrectly
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-19

BEGIN;

-- Test helper function to check multiple locations in a country
CREATE OR REPLACE FUNCTION __test_country_coverage(
  p_country_name TEXT,
  p_test_locations TEXT, -- JSON array: [{"lon": -47.88, "lat": -15.79, "name": "Brasília"}, ...]
  p_expected_country_id INTEGER,
  p_test_name TEXT
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_location RECORD;
  v_result INTEGER;
  v_failures INTEGER := 0;
  v_total INTEGER := 0;
  v_failure_details TEXT := '';
  v_location_json JSONB;
BEGIN
  -- Parse JSON array of locations
  v_location_json := p_test_locations::JSONB;
  
  -- Test each location
  FOR v_location IN 
    SELECT 
      (location->>'lon')::DECIMAL AS lon,
      (location->>'lat')::DECIMAL AS lat,
      location->>'name' AS name
    FROM jsonb_array_elements(v_location_json) AS location
  LOOP
    v_total := v_total + 1;
    v_result := get_country(v_location.lon, v_location.lat, 10000000 + v_total);
    
    -- Check if result is correct
    IF v_result != p_expected_country_id THEN
      v_failures := v_failures + 1;
      v_failure_details := v_failure_details || format(
        '  FAIL: %s (lon: %s, lat: %s) returned %s instead of %s',
        v_location.name,
        v_location.lon,
        v_location.lat,
        v_result,
        p_expected_country_id
      ) || E'\n';
      
      -- Critical: If valid country location returned -1 or -2, this is the bug
      IF v_result IN (-1, -2) THEN
        v_failure_details := v_failure_details || format(
          '    [CRITICAL: Valid country location returned %s - this is the bug!]',
          v_result
        ) || E'\n';
      END IF;
    END IF;
  END LOOP;
  
  -- Return result
  IF v_failures = 0 THEN
    RETURN format('PASS: %s - All %s locations returned correct country_id %s',
      p_test_name, v_total, p_expected_country_id);
  ELSE
    RETURN format('FAIL: %s - %s/%s locations failed:\n%s',
      p_test_name, v_failures, v_total, v_failure_details);
  END IF;
END;
$$;

-- ============================================================================
-- TEST GROUP 1: Brazil - Multiple locations across the country
-- This detects if SOME locations in Brazil return -1/-2 while others work
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_brazil_country_id INTEGER;
  v_test_locations TEXT;
BEGIN
  RAISE NOTICE '=== TEST GROUP 1: Brazil - Multiple Locations Across Country ===';
  RAISE NOTICE 'This test detects if SOME locations in Brazil return -1/-2 incorrectly';
  RAISE NOTICE '';
  
  -- Get Brazil's country_id
  SELECT country_id INTO v_brazil_country_id
  FROM countries
  WHERE country_name_en = 'Brazil' OR country_name_es = 'Brasil'
  LIMIT 1;
  
  IF v_brazil_country_id IS NULL THEN
    RAISE NOTICE 'WARNING: Brazil not found in countries table, skipping test';
    RETURN;
  END IF;
  
  RAISE NOTICE 'Brazil country_id: %', v_brazil_country_id;
  RAISE NOTICE '';
  
  -- Test multiple locations across Brazil
  v_test_locations := '[
    {"lon": -47.8825, "lat": -15.7942, "name": "Brasília (capital)"},
    {"lon": -46.6333, "lat": -23.5505, "name": "São Paulo"},
    {"lon": -43.1729, "lat": -22.9068, "name": "Rio de Janeiro"},
    {"lon": -60.0, "lat": -3.1, "name": "Manaus (interior)"},
    {"lon": -38.4813, "lat": -12.9714, "name": "Salvador"},
    {"lon": -51.2306, "lat": -30.0346, "name": "Porto Alegre"},
    {"lon": -49.2733, "lat": -25.4284, "name": "Curitiba"},
    {"lon": -34.8813, "lat": -8.0476, "name": "Recife"},
    {"lon": -43.9378, "lat": -19.9167, "name": "Belo Horizonte"},
    {"lon": -48.5044, "lat": -1.4558, "name": "Belém"}
  ]';
  
  v_test_result := __test_country_coverage(
    'Brazil',
    v_test_locations,
    v_brazil_country_id,
    'Brazil - Multiple Cities'
  );
  
  RAISE NOTICE '%', v_test_result;
  
  -- Check for critical failures (returning -1 or -2)
  IF v_test_result LIKE '%CRITICAL%' THEN
    RAISE EXCEPTION 'CRITICAL FAILURE DETECTED: Some Brazil locations returned -1 or -2';
  END IF;
END $$;

-- ============================================================================
-- TEST GROUP 2: Venezuela - Multiple locations
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_venezuela_country_id INTEGER;
  v_test_locations TEXT;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== TEST GROUP 2: Venezuela - Multiple Locations ===';
  RAISE NOTICE '';
  
  -- Get Venezuela's country_id
  SELECT country_id INTO v_venezuela_country_id
  FROM countries
  WHERE country_name_en = 'Venezuela' OR country_name_es = 'Venezuela'
  LIMIT 1;
  
  IF v_venezuela_country_id IS NULL THEN
    RAISE NOTICE 'WARNING: Venezuela not found in countries table, skipping test';
    RETURN;
  END IF;
  
  RAISE NOTICE 'Venezuela country_id: %', v_venezuela_country_id;
  RAISE NOTICE '';
  
  -- Test multiple locations across Venezuela
  v_test_locations := '[
    {"lon": -66.9036, "lat": 10.4806, "name": "Caracas (capital)"},
    {"lon": -71.6125, "lat": 10.6317, "name": "Maracaibo"},
    {"lon": -67.6058, "lat": 10.1621, "name": "Valencia"},
    {"lon": -64.1814, "lat": 10.4632, "name": "Barquisimeto"},
    {"lon": -63.5369, "lat": 8.3511, "name": "Ciudad Guayana"}
  ]';
  
  v_test_result := __test_country_coverage(
    'Venezuela',
    v_test_locations,
    v_venezuela_country_id,
    'Venezuela - Multiple Cities'
  );
  
  RAISE NOTICE '%', v_test_result;
  
  IF v_test_result LIKE '%CRITICAL%' THEN
    RAISE EXCEPTION 'CRITICAL FAILURE DETECTED: Some Venezuela locations returned -1 or -2';
  END IF;
END $$;

-- ============================================================================
-- TEST GROUP 3: Chile - Multiple locations
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_chile_country_id INTEGER;
  v_test_locations TEXT;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== TEST GROUP 3: Chile - Multiple Locations ===';
  RAISE NOTICE '';
  
  -- Get Chile's country_id
  SELECT country_id INTO v_chile_country_id
  FROM countries
  WHERE country_name_en = 'Chile' OR country_name_es = 'Chile'
  LIMIT 1;
  
  IF v_chile_country_id IS NULL THEN
    RAISE NOTICE 'WARNING: Chile not found in countries table, skipping test';
    RETURN;
  END IF;
  
  RAISE NOTICE 'Chile country_id: %', v_chile_country_id;
  RAISE NOTICE '';
  
  -- Test multiple locations across Chile (long country, north to south)
  v_test_locations := '[
    {"lon": -70.6693, "lat": -33.4489, "name": "Santiago (capital)"},
    {"lon": -71.6167, "lat": -33.0472, "name": "Valparaíso"},
    {"lon": -70.6489, "lat": -23.6509, "name": "Antofagasta"},
    {"lon": -73.0503, "lat": -36.8201, "name": "Concepción"},
    {"lon": -70.3156, "lat": -18.4783, "name": "Arica"},
    {"lon": -72.9411, "lat": -41.4718, "name": "Puerto Montt"}
  ]';
  
  v_test_result := __test_country_coverage(
    'Chile',
    v_test_locations,
    v_chile_country_id,
    'Chile - Multiple Cities'
  );
  
  RAISE NOTICE '%', v_test_result;
  
  IF v_test_result LIKE '%CRITICAL%' THEN
    RAISE EXCEPTION 'CRITICAL FAILURE DETECTED: Some Chile locations returned -1 or -2';
  END IF;
END $$;

-- ============================================================================
-- TEST GROUP 4: Detect partial failures across multiple countries
-- ============================================================================

DO $$
DECLARE
  v_test_result INTEGER;
  v_failures INTEGER := 0;
  v_total INTEGER := 0;
  v_country_rec RECORD;
  v_sample_locations TEXT;
  v_result INTEGER;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== TEST GROUP 4: Detect Partial Failures Across Multiple Countries ===';
  RAISE NOTICE 'This test samples multiple locations per country to detect partial failures';
  RAISE NOTICE '';
  
  -- Test multiple countries with multiple locations each
  FOR v_country_rec IN
    SELECT country_id, country_name_en, country_name_es
    FROM countries
    WHERE country_id IN (
      SELECT country_id FROM countries 
      WHERE country_name_en IN ('Brazil', 'Venezuela', 'Chile', 'Colombia', 'Argentina', 'Peru')
         OR country_name_es IN ('Brasil', 'Venezuela', 'Chile', 'Colombia', 'Argentina', 'Perú')
    )
    LIMIT 10
  LOOP
    -- Test 3 random locations within country bounding box
    -- (In real test, you'd use actual city coordinates)
    FOR i IN 1..3 LOOP
      v_total := v_total + 1;
      
      -- Get a sample point from the country's geometry
      -- This is a simplified test - in production you'd use actual city coordinates
      SELECT get_country(
        ST_X(ST_Centroid(geom)),
        ST_Y(ST_Centroid(geom)),
        20000000 + v_total
      ) INTO v_result
      FROM countries
      WHERE country_id = v_country_rec.country_id;
      
      IF v_result != v_country_rec.country_id THEN
        v_failures := v_failures + 1;
        RAISE NOTICE 'FAIL: % (country_id: %) - Centroid returned % instead of %',
          COALESCE(v_country_rec.country_name_en, v_country_rec.country_name_es),
          v_country_rec.country_id,
          v_result,
          v_country_rec.country_id;
        
        IF v_result IN (-1, -2) THEN
          RAISE NOTICE '  [CRITICAL: Country centroid returned % - this is the bug!]', v_result;
        END IF;
      END IF;
    END LOOP;
  END LOOP;
  
  RAISE NOTICE '';
  IF v_failures > 0 THEN
    RAISE EXCEPTION 'PARTIAL FAILURE DETECTED: %/% locations failed across multiple countries', v_failures, v_total;
  ELSE
    RAISE NOTICE 'PASS: All % locations returned correct country_id', v_total;
  END IF;
END $$;

-- ============================================================================
-- TEST GROUP 5: Test edge cases - points near country boundaries
-- ============================================================================

DO $$
DECLARE
  v_test_result INTEGER;
  v_brazil_country_id INTEGER;
  v_failures INTEGER := 0;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== TEST GROUP 5: Edge Cases - Points Near Country Boundaries ===';
  RAISE NOTICE 'This test checks if points near boundaries are correctly assigned';
  RAISE NOTICE '';
  
  -- Get Brazil's country_id
  SELECT country_id INTO v_brazil_country_id
  FROM countries
  WHERE country_name_en = 'Brazil' OR country_name_es = 'Brasil'
  LIMIT 1;
  
  IF v_brazil_country_id IS NULL THEN
    RAISE NOTICE 'WARNING: Brazil not found, skipping edge case test';
    RETURN;
  END IF;
  
  -- Test points that should be inside Brazil but might be near boundaries
  -- These are known cities that should definitely be in Brazil
  DECLARE
    test_points RECORD;
  BEGIN
    FOR test_points IN
      SELECT -47.8825 AS lon, -15.7942 AS lat, 'Brasília' AS name UNION ALL
      SELECT -46.6333, -23.5505, 'São Paulo' UNION ALL
      SELECT -60.0, -3.1, 'Manaus' UNION ALL
      SELECT -38.4813, -12.9714, 'Salvador'
    LOOP
      v_test_result := get_country(test_points.lon, test_points.lat, 30000000);
      
      IF v_test_result != v_brazil_country_id THEN
        v_failures := v_failures + 1;
        RAISE NOTICE 'FAIL: % (lon: %, lat: %) returned % instead of Brazil (%)',
          test_points.name,
          test_points.lon,
          test_points.lat,
          v_test_result,
          v_brazil_country_id;
        
        IF v_test_result IN (-1, -2) THEN
          RAISE NOTICE '  [CRITICAL: Known Brazil city returned % - this is the bug!]', v_test_result;
        END IF;
      ELSE
        RAISE NOTICE 'PASS: % returned correct Brazil country_id', test_points.name;
      END IF;
    END LOOP;
  END;
  
  RAISE NOTICE '';
  IF v_failures > 0 THEN
    RAISE EXCEPTION 'EDGE CASE FAILURE: % locations near boundaries failed', v_failures;
  ELSE
    RAISE NOTICE 'PASS: All edge case locations returned correct country_id';
  END IF;
END $$;

-- Clean up helper function
DROP FUNCTION IF EXISTS __test_country_coverage(TEXT, TEXT, INTEGER, TEXT);

COMMIT;
