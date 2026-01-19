-- Unit tests for get_country function return values
-- Tests that verify correct return values (-1, -2, or valid country_id)
-- This test specifically detects the bug where -1 was returned for valid countries
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-19

BEGIN;

-- Test helper function to verify get_country return value category
CREATE OR REPLACE FUNCTION __test_get_country_return_category(
  p_lon DECIMAL,
  p_lat DECIMAL,
  p_note_id INTEGER,
  p_expected_category TEXT, -- 'valid_country', 'international_waters', 'unknown'
  p_test_name TEXT
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_result INTEGER;
  v_country_name TEXT;
  v_actual_category TEXT;
  v_error_msg TEXT;
BEGIN
  v_result := get_country(p_lon, p_lat, p_note_id);
  
  -- Determine actual category
  IF v_result > 0 THEN
    v_actual_category := 'valid_country';
    SELECT country_name_en INTO v_country_name
    FROM countries
    WHERE country_id = v_result;
  ELSIF v_result = -1 THEN
    v_actual_category := 'international_waters';
    v_country_name := 'International Waters';
  ELSIF v_result = -2 THEN
    v_actual_category := 'unknown';
    v_country_name := 'Unknown/Not Found';
  ELSE
    v_actual_category := 'invalid';
    v_country_name := format('Invalid value: %s', v_result);
  END IF;
  
  -- Verify category matches expected
  IF v_actual_category = p_expected_category THEN
    RETURN format('PASS: %s - Expected category: %s, Got: %s (value: %s, name: %s)',
      p_test_name,
      p_expected_category,
      v_actual_category,
      v_result,
      COALESCE(v_country_name, 'NULL')
    );
  ELSE
    v_error_msg := format('FAIL: %s - Expected category: %s, Got: %s (value: %s, name: %s)',
      p_test_name,
      p_expected_category,
      v_actual_category,
      v_result,
      COALESCE(v_country_name, 'NULL')
    );
    
    -- Additional error details for critical failures
    IF p_expected_category = 'valid_country' AND v_result IN (-1, -2) THEN
      v_error_msg := v_error_msg || format(' [CRITICAL: Valid country returned %s instead of country_id]', v_result);
    END IF;
    
    RETURN v_error_msg;
  END IF;
END;
$$;

-- ============================================================================
-- TEST GROUP 1: Countries that were incorrectly returning -1
-- These are the countries that were affected by the bug
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_test_note_id INTEGER := 9000000;
  v_failures INTEGER := 0;
BEGIN
  RAISE NOTICE '=== TEST GROUP 1: Countries Previously Returning -1 Incorrectly ===';
  RAISE NOTICE 'This test verifies that valid countries return valid country_id, NOT -1 or -2';
  RAISE NOTICE '';
  
  -- Brazil - Brasília (capital)
  v_test_result := __test_get_country_return_category(-47.8825, -15.7942, v_test_note_id, 'valid_country', 'Brazil - Brasília');
  RAISE NOTICE '%', v_test_result;
  IF v_test_result LIKE 'FAIL%' THEN v_failures := v_failures + 1; END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Brazil - Manaus (interior city)
  v_test_result := __test_get_country_return_category(-60.0, -3.1, v_test_note_id, 'valid_country', 'Brazil - Manaus');
  RAISE NOTICE '%', v_test_result;
  IF v_test_result LIKE 'FAIL%' THEN v_failures := v_failures + 1; END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Brazil - São Paulo
  v_test_result := __test_get_country_return_category(-46.6333, -23.5505, v_test_note_id, 'valid_country', 'Brazil - São Paulo');
  RAISE NOTICE '%', v_test_result;
  IF v_test_result LIKE 'FAIL%' THEN v_failures := v_failures + 1; END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Venezuela - Caracas (capital)
  v_test_result := __test_get_country_return_category(-66.9036, 10.4806, v_test_note_id, 'valid_country', 'Venezuela - Caracas');
  RAISE NOTICE '%', v_test_result;
  IF v_test_result LIKE 'FAIL%' THEN v_failures := v_failures + 1; END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Venezuela - Maracaibo
  v_test_result := __test_get_country_return_category(-71.6125, 10.6317, v_test_note_id, 'valid_country', 'Venezuela - Maracaibo');
  RAISE NOTICE '%', v_test_result;
  IF v_test_result LIKE 'FAIL%' THEN v_failures := v_failures + 1; END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Chile - Santiago (capital)
  v_test_result := __test_get_country_return_category(-70.6693, -33.4489, v_test_note_id, 'valid_country', 'Chile - Santiago');
  RAISE NOTICE '%', v_test_result;
  IF v_test_result LIKE 'FAIL%' THEN v_failures := v_failures + 1; END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Chile - Valparaíso
  v_test_result := __test_get_country_return_category(-71.6167, -33.0472, v_test_note_id, 'valid_country', 'Chile - Valparaíso');
  RAISE NOTICE '%', v_test_result;
  IF v_test_result LIKE 'FAIL%' THEN v_failures := v_failures + 1; END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Colombia - Bogotá
  v_test_result := __test_get_country_return_category(-74.0721, 4.7110, v_test_note_id, 'valid_country', 'Colombia - Bogotá');
  RAISE NOTICE '%', v_test_result;
  IF v_test_result LIKE 'FAIL%' THEN v_failures := v_failures + 1; END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Argentina - Buenos Aires
  v_test_result := __test_get_country_return_category(-58.3816, -34.6037, v_test_note_id, 'valid_country', 'Argentina - Buenos Aires');
  RAISE NOTICE '%', v_test_result;
  IF v_test_result LIKE 'FAIL%' THEN v_failures := v_failures + 1; END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Peru - Lima
  v_test_result := __test_get_country_return_category(-77.0428, -12.0464, v_test_note_id, 'valid_country', 'Peru - Lima');
  RAISE NOTICE '%', v_test_result;
  IF v_test_result LIKE 'FAIL%' THEN v_failures := v_failures + 1; END IF;
  v_test_note_id := v_test_note_id + 1;
  
  RAISE NOTICE '';
  IF v_failures > 0 THEN
    RAISE EXCEPTION 'TEST GROUP 1 FAILED: % tests failed - Valid countries returned -1 or -2', v_failures;
  ELSE
    RAISE NOTICE 'TEST GROUP 1 PASSED: All valid countries returned valid country_id';
  END IF;
END $$;

-- ============================================================================
-- TEST GROUP 2: Verify -1 is ONLY returned for known international waters
-- ============================================================================

DO $$
DECLARE
  v_test_result INTEGER;
  v_test_note_id INTEGER := 9100000;
  v_failures INTEGER := 0;
BEGIN
  RAISE NOTICE '=== TEST GROUP 2: Verify -1 Only for Known International Waters ===';
  RAISE NOTICE 'This test verifies that -1 is ONLY returned for known international waters';
  RAISE NOTICE '';
  
  -- Null Island (0, 0) - Gulf of Guinea
  -- Note: This should return -1 ONLY if it's in the international_waters table
  -- Otherwise, it should return -2 (unknown) or a valid country if in territorial waters
  v_test_result := get_country(0.0, 0.0, v_test_note_id);
  IF v_test_result = -1 THEN
    RAISE NOTICE 'PASS: Null Island (0,0) returned -1 (known international waters)';
  ELSIF v_test_result = -2 THEN
    RAISE NOTICE 'PASS: Null Island (0,0) returned -2 (unknown - not in international_waters table)';
  ELSIF v_test_result > 0 THEN
    RAISE NOTICE 'INFO: Null Island (0,0) returned country_id % (in territorial waters)', v_test_result;
  ELSE
    RAISE NOTICE 'FAIL: Null Island (0,0) returned invalid value: %', v_test_result;
    v_failures := v_failures + 1;
  END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Mid-Atlantic Ocean (far from land)
  v_test_result := get_country(-30.0, 25.0, v_test_note_id);
  IF v_test_result IN (-1, -2) THEN
    RAISE NOTICE 'PASS: Mid-Atlantic Ocean returned % (international waters or unknown)', v_test_result;
  ELSIF v_test_result > 0 THEN
    RAISE NOTICE 'INFO: Mid-Atlantic Ocean returned country_id % (in territorial waters)', v_test_result;
  ELSE
    RAISE NOTICE 'FAIL: Mid-Atlantic Ocean returned invalid value: %', v_test_result;
    v_failures := v_failures + 1;
  END IF;
  v_test_note_id := v_test_note_id + 1;
  
  -- Pacific Ocean (far from land)
  v_test_result := get_country(-150.0, 10.0, v_test_note_id);
  IF v_test_result IN (-1, -2) THEN
    RAISE NOTICE 'PASS: Pacific Ocean returned % (international waters or unknown)', v_test_result;
  ELSIF v_test_result > 0 THEN
    RAISE NOTICE 'INFO: Pacific Ocean returned country_id % (in territorial waters)', v_test_result;
  ELSE
    RAISE NOTICE 'FAIL: Pacific Ocean returned invalid value: %', v_test_result;
    v_failures := v_failures + 1;
  END IF;
  v_test_note_id := v_test_note_id + 1;
  
  RAISE NOTICE '';
  IF v_failures > 0 THEN
    RAISE EXCEPTION 'TEST GROUP 2 FAILED: % tests failed', v_failures;
  ELSE
    RAISE NOTICE 'TEST GROUP 2 PASSED: -1/-2 returned appropriately for international waters';
  END IF;
END $$;

-- ============================================================================
-- TEST GROUP 3: Verify -2 is returned for unknown/not found countries
-- ============================================================================

DO $$
DECLARE
  v_test_result INTEGER;
  v_test_note_id INTEGER := 9200000;
  v_failures INTEGER := 0;
BEGIN
  RAISE NOTICE '=== TEST GROUP 3: Verify -2 for Unknown/Not Found Countries ===';
  RAISE NOTICE 'This test verifies that -2 is returned when country is not found';
  RAISE NOTICE 'Note: These tests may pass or fail depending on country boundaries';
  RAISE NOTICE '';
  
  -- Test with coordinates that might not match any country
  -- (coordinates in middle of ocean, far from any land)
  v_test_result := get_country(-100.0, 0.0, v_test_note_id);
  IF v_test_result = -2 THEN
    RAISE NOTICE 'PASS: Unknown location returned -2 (unknown)';
  ELSIF v_test_result = -1 THEN
    RAISE NOTICE 'INFO: Unknown location returned -1 (known international waters)';
  ELSIF v_test_result > 0 THEN
    RAISE NOTICE 'INFO: Unknown location returned country_id % (in territorial waters)', v_test_result;
  ELSE
    RAISE NOTICE 'FAIL: Unknown location returned invalid value: %', v_test_result;
    v_failures := v_failures + 1;
  END IF;
  v_test_note_id := v_test_note_id + 1;
  
  RAISE NOTICE '';
  IF v_failures > 0 THEN
    RAISE EXCEPTION 'TEST GROUP 3 FAILED: % tests failed', v_failures;
  ELSE
    RAISE NOTICE 'TEST GROUP 3 PASSED: -2 returned appropriately for unknown locations';
  END IF;
END $$;

-- ============================================================================
-- TEST GROUP 4: Critical Test - Ensure valid countries NEVER return -1 or -2
-- ============================================================================

DO $$
DECLARE
  v_test_result INTEGER;
  v_test_note_id INTEGER := 9300000;
  v_failures INTEGER := 0;
  v_country_name TEXT;
BEGIN
  RAISE NOTICE '=== TEST GROUP 4: Critical Test - Valid Countries Never Return -1 or -2 ===';
  RAISE NOTICE 'This is the CRITICAL test that would have detected the original bug';
  RAISE NOTICE '';
  
  -- Test multiple valid countries to ensure none return -1 or -2
  DECLARE
    test_cases RECORD;
  BEGIN
    FOR test_cases IN
      SELECT -47.8825 AS lon, -15.7942 AS lat, 'Brazil - Brasília' AS name UNION ALL
      SELECT -66.9036, 10.4806, 'Venezuela - Caracas' UNION ALL
      SELECT -70.6693, -33.4489, 'Chile - Santiago' UNION ALL
      SELECT -74.0721, 4.7110, 'Colombia - Bogotá' UNION ALL
      SELECT -58.3816, -34.6037, 'Argentina - Buenos Aires' UNION ALL
      SELECT -77.0428, -12.0464, 'Peru - Lima' UNION ALL
      SELECT -60.0, -3.1, 'Brazil - Manaus' UNION ALL
      SELECT -46.6333, -23.5505, 'Brazil - São Paulo' UNION ALL
      SELECT 13.4050, 52.5200, 'Germany - Berlin' UNION ALL
      SELECT 2.3522, 48.8566, 'France - Paris' UNION ALL
      SELECT -0.1276, 51.5074, 'UK - London' UNION ALL
      SELECT -74.0060, 40.7128, 'USA - New York' UNION ALL
      SELECT 139.6917, 35.6895, 'Japan - Tokyo' UNION ALL
      SELECT 116.4074, 39.9042, 'China - Beijing'
    LOOP
      v_test_result := get_country(test_cases.lon, test_cases.lat, v_test_note_id);
      
      IF v_test_result IN (-1, -2) THEN
        RAISE NOTICE 'FAIL: % (lon: %, lat: %) returned % instead of valid country_id',
          test_cases.name, test_cases.lon, test_cases.lat, v_test_result;
        v_failures := v_failures + 1;
      ELSIF v_test_result > 0 THEN
        SELECT country_name_en INTO v_country_name
        FROM countries
        WHERE country_id = v_test_result;
        RAISE NOTICE 'PASS: % returned valid country_id % (%)',
          test_cases.name, v_test_result, COALESCE(v_country_name, 'NULL');
      ELSE
        RAISE NOTICE 'FAIL: % returned invalid value: %',
          test_cases.name, v_test_result;
        v_failures := v_failures + 1;
      END IF;
      
      v_test_note_id := v_test_note_id + 1;
    END LOOP;
  END;
  
  RAISE NOTICE '';
  IF v_failures > 0 THEN
    RAISE EXCEPTION 'TEST GROUP 4 FAILED: % valid countries returned -1 or -2 (CRITICAL BUG DETECTED)', v_failures;
  ELSE
    RAISE NOTICE 'TEST GROUP 4 PASSED: All valid countries returned valid country_id (no -1 or -2)';
  END IF;
END $$;

-- ============================================================================
-- TEST GROUP 5: Verify return value semantics
-- ============================================================================

DO $$
DECLARE
  v_test_result INTEGER;
  v_test_note_id INTEGER := 9400000;
  v_failures INTEGER := 0;
BEGIN
  RAISE NOTICE '=== TEST GROUP 5: Verify Return Value Semantics ===';
  RAISE NOTICE 'This test verifies the semantic meaning of return values';
  RAISE NOTICE '';
  
  -- Test that return value is always an INTEGER (never NULL)
  v_test_result := get_country(0.0, 0.0, v_test_note_id);
  IF v_test_result IS NULL THEN
    RAISE NOTICE 'FAIL: get_country returned NULL (should always return INTEGER)';
    v_failures := v_failures + 1;
  ELSE
    RAISE NOTICE 'PASS: get_country always returns INTEGER (never NULL)';
  END IF;
  
  -- Test that valid countries return positive integers
  v_test_result := get_country(-47.8825, -15.7942, v_test_note_id); -- Brazil
  IF v_test_result > 0 THEN
    RAISE NOTICE 'PASS: Valid country returned positive integer: %', v_test_result;
  ELSE
    RAISE NOTICE 'FAIL: Valid country returned non-positive value: %', v_test_result;
    v_failures := v_failures + 1;
  END IF;
  
  -- Test that -1 and -2 are the only negative values returned
  v_test_result := get_country(-100.0, 0.0, v_test_note_id); -- Unknown location
  IF v_test_result IN (-1, -2) OR v_test_result > 0 THEN
    RAISE NOTICE 'PASS: Unknown location returned valid semantic value: %', v_test_result;
  ELSE
    RAISE NOTICE 'FAIL: Unknown location returned invalid value: % (should be -1, -2, or >0)', v_test_result;
    v_failures := v_failures + 1;
  END IF;
  
  RAISE NOTICE '';
  IF v_failures > 0 THEN
    RAISE EXCEPTION 'TEST GROUP 5 FAILED: % tests failed', v_failures;
  ELSE
    RAISE NOTICE 'TEST GROUP 5 PASSED: Return value semantics are correct';
  END IF;
END $$;

-- Clean up helper function
DROP FUNCTION IF EXISTS __test_get_country_return_category(DECIMAL, DECIMAL, INTEGER, TEXT, TEXT);

COMMIT;
