-- Unit tests for get_country function
-- Tests the function with capital cities, special cases, disputed areas,
-- and non-continental territories.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-23

BEGIN;

-- Test helper function to verify get_country result
CREATE OR REPLACE FUNCTION __test_get_country(
  p_lon DECIMAL,
  p_lat DECIMAL,
  p_note_id INTEGER,
  p_expected_country_id INTEGER,
  p_test_name TEXT
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_result INTEGER;
  v_country_name TEXT;
BEGIN
  v_result := get_country(p_lon, p_lat, p_note_id);
  
  IF v_result = p_expected_country_id THEN
    SELECT country_name_en INTO v_country_name
    FROM countries
    WHERE country_id = v_result;
    
    RETURN format('PASS: %s - Expected: %s (%s), Got: %s (%s)',
      p_test_name,
      p_expected_country_id,
      COALESCE(v_country_name, 'NULL'),
      v_result,
      COALESCE(v_country_name, 'NULL')
    );
  ELSE
    SELECT country_name_en INTO v_country_name
    FROM countries
    WHERE country_id = v_result;
    
    RETURN format('FAIL: %s - Expected: %s, Got: %s (%s)',
      p_test_name,
      p_expected_country_id,
      v_result,
      COALESCE(v_country_name, 'NULL')
    );
  END IF;
END;
$$;

-- ============================================================================
-- TEST GROUP 1: Capital Cities of Top 50 Countries
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_test_note_id INTEGER := 1000000;
BEGIN
  RAISE NOTICE '=== TEST GROUP 1: Capital Cities ===';
  
  -- United States - Washington D.C.
  v_test_result := __test_get_country(-77.0369, 38.9072, v_test_note_id, 148838, 'USA - Washington D.C.');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- China - Beijing
  v_test_result := __test_get_country(116.4074, 39.9042, v_test_note_id, 270056, 'China - Beijing');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- India - New Delhi
  v_test_result := __test_get_country(77.2090, 28.6139, v_test_note_id, 304716, 'India - New Delhi');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Brazil - Brasília
  v_test_result := __test_get_country(-47.8825, -15.7942, v_test_note_id, 59470, 'Brazil - Brasília');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Russia - Moscow
  v_test_result := __test_get_country(37.6173, 55.7558, v_test_note_id, 60189, 'Russia - Moscow');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Japan - Tokyo
  v_test_result := __test_get_country(139.6917, 35.6895, v_test_note_id, 382313, 'Japan - Tokyo');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Germany - Berlin
  v_test_result := __test_get_country(13.4050, 52.5200, v_test_note_id, 51477, 'Germany - Berlin');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- United Kingdom - London
  v_test_result := __test_get_country(-0.1276, 51.5074, v_test_note_id, 62149, 'UK - London');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- France - Paris
  v_test_result := __test_get_country(2.3522, 48.8566, v_test_note_id, 2202162, 'France - Paris');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Italy - Rome
  v_test_result := __test_get_country(12.4964, 41.9028, v_test_note_id, 365331, 'Italy - Rome');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Spain - Madrid
  v_test_result := __test_get_country(-3.7038, 40.4168, v_test_note_id, 1311341, 'Spain - Madrid');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Canada - Ottawa
  v_test_result := __test_get_country(-75.6972, 45.4215, v_test_note_id, 1428125, 'Canada - Ottawa');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Australia - Canberra
  v_test_result := __test_get_country(149.1300, -35.2809, v_test_note_id, 80500, 'Australia - Canberra');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Mexico - Mexico City
  v_test_result := __test_get_country(-99.1332, 19.4326, v_test_note_id, 114686, 'Mexico - Mexico City');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Indonesia - Jakarta
  v_test_result := __test_get_country(106.8451, -6.2088, v_test_note_id, 304751, 'Indonesia - Jakarta');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- South Korea - Seoul
  v_test_result := __test_get_country(126.9780, 37.5665, v_test_note_id, 307756, 'South Korea - Seoul');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Argentina - Buenos Aires
  v_test_result := __test_get_country(-58.3816, -34.6037, v_test_note_id, 286393, 'Argentina - Buenos Aires');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Netherlands - Amsterdam
  v_test_result := __test_get_country(4.9041, 52.3676, v_test_note_id, 2323309, 'Netherlands - Amsterdam');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Saudi Arabia - Riyadh
  v_test_result := __test_get_country(46.6753, 24.7136, v_test_note_id, 307584, 'Saudi Arabia - Riyadh');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Turkey - Ankara
  v_test_result := __test_get_country(32.8597, 39.9334, v_test_note_id, 174737, 'Turkey - Ankara');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Poland - Warsaw
  v_test_result := __test_get_country(21.0122, 52.2297, v_test_note_id, 49715, 'Poland - Warsaw');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Belgium - Brussels
  v_test_result := __test_get_country(4.3517, 50.8503, v_test_note_id, 52411, 'Belgium - Brussels');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Sweden - Stockholm
  v_test_result := __test_get_country(18.0686, 59.3293, v_test_note_id, 52822, 'Sweden - Stockholm');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Switzerland - Bern
  v_test_result := __test_get_country(7.4474, 46.9481, v_test_note_id, 51701, 'Switzerland - Bern');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Norway - Oslo
  v_test_result := __test_get_country(10.7522, 59.9139, v_test_note_id, 2978650, 'Norway - Oslo');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Austria - Vienna
  v_test_result := __test_get_country(16.3738, 48.2082, v_test_note_id, 16239, 'Austria - Vienna');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Thailand - Bangkok
  v_test_result := __test_get_country(100.5018, 13.7563, v_test_note_id, 2067731, 'Thailand - Bangkok');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- United Arab Emirates - Abu Dhabi
  v_test_result := __test_get_country(54.3773, 24.4539, v_test_note_id, 307763, 'UAE - Abu Dhabi');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Israel - Jerusalem
  v_test_result := __test_get_country(35.2137, 31.7683, v_test_note_id, 1473946, 'Israel - Jerusalem');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Singapore - Singapore
  v_test_result := __test_get_country(103.8198, 1.3521, v_test_note_id, 536780, 'Singapore - Singapore');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Malaysia - Kuala Lumpur
  v_test_result := __test_get_country(101.6869, 3.1390, v_test_note_id, 2108121, 'Malaysia - Kuala Lumpur');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- South Africa - Cape Town (legislative)
  v_test_result := __test_get_country(18.4241, -33.9249, v_test_note_id, 87565, 'South Africa - Cape Town');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Philippines - Manila
  v_test_result := __test_get_country(120.9842, 14.5995, v_test_note_id, 443174, 'Philippines - Manila');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Denmark - Copenhagen
  v_test_result := __test_get_country(12.5683, 55.6761, v_test_note_id, 50046, 'Denmark - Copenhagen');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Egypt - Cairo
  v_test_result := __test_get_country(31.2357, 30.0444, v_test_note_id, 1473947, 'Egypt - Cairo');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Finland - Helsinki
  v_test_result := __test_get_country(24.9384, 60.1699, v_test_note_id, 54224, 'Finland - Helsinki');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Chile - Santiago
  v_test_result := __test_get_country(-70.6693, -33.4489, v_test_note_id, 167454, 'Chile - Santiago');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Czech Republic - Prague
  v_test_result := __test_get_country(14.4378, 50.0755, v_test_note_id, 51684, 'Czechia - Prague');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Romania - Bucharest
  v_test_result := __test_get_country(26.1025, 44.4268, v_test_note_id, 90689, 'Romania - Bucharest');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- New Zealand - Wellington
  v_test_result := __test_get_country(174.7762, -41.2865, v_test_note_id, 556706, 'New Zealand - Wellington');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Portugal - Lisbon
  v_test_result := __test_get_country(-9.1393, 38.7223, v_test_note_id, 295480, 'Portugal - Lisbon');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Greece - Athens
  v_test_result := __test_get_country(23.7275, 37.9838, v_test_note_id, 192307, 'Greece - Athens');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Ireland - Dublin
  v_test_result := __test_get_country(-6.2603, 53.3498, v_test_note_id, 62273, 'Ireland - Dublin');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Colombia - Bogotá
  v_test_result := __test_get_country(-74.0721, 4.7110, v_test_note_id, 120027, 'Colombia - Bogotá');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Peru - Lima
  v_test_result := __test_get_country(-77.0428, -12.0464, v_test_note_id, 288247, 'Peru - Lima');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Vietnam - Hanoi
  v_test_result := __test_get_country(105.8342, 21.0285, v_test_note_id, 49915, 'Vietnam - Hanoi');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Bangladesh - Dhaka
  v_test_result := __test_get_country(90.4125, 23.8103, v_test_note_id, 184640, 'Bangladesh - Dhaka');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Pakistan - Islamabad
  v_test_result := __test_get_country(73.0479, 33.6844, v_test_note_id, 307573, 'Pakistan - Islamabad');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Nigeria - Abuja
  v_test_result := __test_get_country(7.4951, 9.0765, v_test_note_id, 192787, 'Nigeria - Abuja');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Kenya - Nairobi
  v_test_result := __test_get_country(36.8219, -1.2921, v_test_note_id, 192798, 'Kenya - Nairobi');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
END $$;

-- ============================================================================
-- TEST GROUP 2: Special Cases - Null Island
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_test_note_id INTEGER := 2000000;
BEGIN
  RAISE NOTICE '=== TEST GROUP 2: Null Island ===';
  
  -- Null Island (0, 0) - Gulf of Guinea, should return -1 (international waters)
  v_test_result := __test_get_country(0.0, 0.0, v_test_note_id, -1, 'Null Island - International Waters');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
END $$;

-- ============================================================================
-- TEST GROUP 3: International Waters
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_test_note_id INTEGER := 3000000;
BEGIN
  RAISE NOTICE '=== TEST GROUP 3: International Waters ===';
  
  -- Mid-Atlantic Ocean
  v_test_result := __test_get_country(-30.0, 25.0, v_test_note_id, -1, 'Mid-Atlantic Ocean');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Pacific Ocean (far from land)
  v_test_result := __test_get_country(-150.0, 10.0, v_test_note_id, -1, 'Pacific Ocean - Far from land');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Indian Ocean
  v_test_result := __test_get_country(70.0, -20.0, v_test_note_id, -1, 'Indian Ocean');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
END $$;

-- ============================================================================
-- TEST GROUP 4: Non-Continental Territories - France
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_test_note_id INTEGER := 4000000;
BEGIN
  RAISE NOTICE '=== TEST GROUP 4: French Non-Continental Territories ===';
  
  -- French Guiana - Cayenne (South America)
  v_test_result := __test_get_country(-52.3358, 4.9224, v_test_note_id, 2202162, 'French Guiana - Cayenne');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Réunion - Saint-Denis (Indian Ocean)
  v_test_result := __test_get_country(55.4500, -20.8789, v_test_note_id, 2202162, 'Réunion - Saint-Denis');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Martinique - Fort-de-France (Caribbean)
  v_test_result := __test_get_country(-61.0589, 14.6415, v_test_note_id, 2202162, 'Martinique - Fort-de-France');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Guadeloupe - Basse-Terre (Caribbean)
  v_test_result := __test_get_country(-61.7322, 16.2650, v_test_note_id, 2202162, 'Guadeloupe - Basse-Terre');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- French Polynesia - Papeete (Pacific)
  v_test_result := __test_get_country(-149.5667, -17.5333, v_test_note_id, 2202162, 'French Polynesia - Papeete');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- New Caledonia - Nouméa (Pacific)
  v_test_result := __test_get_country(166.4594, -22.2558, v_test_note_id, 2202162, 'New Caledonia - Nouméa');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
END $$;

-- ============================================================================
-- TEST GROUP 5: Large Countries - Remote Territories
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_test_note_id INTEGER := 5000000;
BEGIN
  RAISE NOTICE '=== TEST GROUP 5: Large Countries - Remote Areas ===';
  
  -- USA - Alaska (Anchorage)
  v_test_result := __test_get_country(-149.9003, 61.2181, v_test_note_id, 148838, 'USA - Alaska (Anchorage)');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- USA - Hawaii (Honolulu)
  v_test_result := __test_get_country(-157.8583, 21.3099, v_test_note_id, 148838, 'USA - Hawaii (Honolulu)');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Russia - Vladivostok (Far East)
  v_test_result := __test_get_country(131.8856, 43.1155, v_test_note_id, 60189, 'Russia - Vladivostok');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Russia - Kaliningrad (European exclave)
  v_test_result := __test_get_country(20.4522, 54.7104, v_test_note_id, 60189, 'Russia - Kaliningrad');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Canada - Vancouver (West Coast)
  v_test_result := __test_get_country(-123.1216, 49.2827, v_test_note_id, 1428125, 'Canada - Vancouver');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Canada - St. John's (East Coast)
  v_test_result := __test_get_country(-52.7126, 47.5615, v_test_note_id, 1428125, 'Canada - St. John''s');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Australia - Perth (West Coast)
  v_test_result := __test_get_country(115.8605, -31.9505, v_test_note_id, 80500, 'Australia - Perth');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Australia - Sydney (East Coast)
  v_test_result := __test_get_country(151.2093, -33.8688, v_test_note_id, 80500, 'Australia - Sydney');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- China - Urumqi (Far West)
  v_test_result := __test_get_country(87.6168, 43.8256, v_test_note_id, 270056, 'China - Urumqi');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- China - Shanghai (East Coast)
  v_test_result := __test_get_country(121.4737, 31.2304, v_test_note_id, 270056, 'China - Shanghai');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
END $$;

-- ============================================================================
-- TEST GROUP 6: Disputed Areas and Border Regions
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_test_note_id INTEGER := 6000000;
BEGIN
  RAISE NOTICE '=== TEST GROUP 6: Disputed Areas and Border Regions ===';
  
  -- Kashmir region (disputed between India and Pakistan)
  -- Testing a point that should be in India
  v_test_result := __test_get_country(74.7973, 34.0837, v_test_note_id, 304716, 'Kashmir - Srinagar (India)');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Gibraltar (British territory, but close to Spain)
  v_test_result := __test_get_country(-5.3536, 36.1408, v_test_note_id, 62149, 'Gibraltar');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Ceuta (Spanish territory in Africa)
  v_test_result := __test_get_country(-5.3167, 35.8886, v_test_note_id, 1311341, 'Ceuta (Spain)');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Melilla (Spanish territory in Africa)
  v_test_result := __test_get_country(-2.9381, 35.2923, v_test_note_id, 1311341, 'Melilla (Spain)');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
END $$;

-- ============================================================================
-- TEST GROUP 7: Edge Cases - Polar Regions
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_test_note_id INTEGER := 7000000;
BEGIN
  RAISE NOTICE '=== TEST GROUP 7: Polar Regions ===';
  
  -- Arctic - Svalbard, Norway
  v_test_result := __test_get_country(15.6389, 78.2232, v_test_note_id, 2978650, 'Arctic - Svalbard (Norway)');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Antarctica - McMurdo Station (should be -1, no country)
  v_test_result := __test_get_country(166.6667, -77.8419, v_test_note_id, -1, 'Antarctica - McMurdo Station');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
END $$;

-- ============================================================================
-- TEST GROUP 8: Island Nations
-- ============================================================================

DO $$
DECLARE
  v_test_result TEXT;
  v_test_note_id INTEGER := 8000000;
BEGIN
  RAISE NOTICE '=== TEST GROUP 8: Island Nations ===';
  
  -- Iceland - Reykjavik
  v_test_result := __test_get_country(-21.8278, 64.1466, v_test_note_id, 299133, 'Iceland - Reykjavik');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Maldives - Malé
  v_test_result := __test_get_country(73.5093, 4.1755, v_test_note_id, 536773, 'Maldives - Malé');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
  -- Fiji - Suva
  v_test_result := __test_get_country(178.4419, -18.1416, v_test_note_id, 571747, 'Fiji - Suva');
  RAISE NOTICE '%', v_test_result;
  v_test_note_id := v_test_note_id + 1;
  
END $$;

-- Clean up helper function
DROP FUNCTION IF EXISTS __test_get_country(DECIMAL, DECIMAL, INTEGER, INTEGER, TEXT);

COMMIT;

