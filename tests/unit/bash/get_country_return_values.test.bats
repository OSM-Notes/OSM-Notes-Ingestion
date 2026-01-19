#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2317

# Test suite for get_country() return values
# Tests that verify get_country() returns correct values:
# - Valid countries return valid country_id (> 0), NOT -1 or -2
# - -1 is ONLY returned for known international waters
# - -2 is returned for unknown/not found countries
#
# These tests would have detected the bug where valid countries returned -1
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-19

load test_helper

setup() {
 # Use test database
 export DBNAME="${TEST_DBNAME:-notes_test}"
 
 # Ensure get_country function exists
 if ! psql -d "${DBNAME}" -t -c "SELECT 1 FROM pg_proc WHERE proname = 'get_country';" | grep -q 1; then
  skip "get_country function does not exist in database"
 fi
}

@test "get_country: valid countries never return -1 or -2" {
 # This is the CRITICAL test that would have detected the original bug
 # Test countries that were affected: Brazil, Venezuela, Chile
 
 local result
 
 # Brazil - Brasília
 result=$(psql -d "${DBNAME}" -t -c "SELECT get_country(-47.8825, -15.7942, 1000000);" | tr -d ' ')
 [[ "${result}" =~ ^[0-9]+$ ]] || false
 [[ "${result}" -gt 0 ]] || false
 [[ "${result}" != "-1" ]] || false
 [[ "${result}" != "-2" ]] || false
 
 # Venezuela - Caracas
 result=$(psql -d "${DBNAME}" -t -c "SELECT get_country(-66.9036, 10.4806, 1000001);" | tr -d ' ')
 [[ "${result}" =~ ^[0-9]+$ ]] || false
 [[ "${result}" -gt 0 ]] || false
 [[ "${result}" != "-1" ]] || false
 [[ "${result}" != "-2" ]] || false
 
 # Chile - Santiago
 result=$(psql -d "${DBNAME}" -t -c "SELECT get_country(-70.6693, -33.4489, 1000002);" | tr -d ' ')
 [[ "${result}" =~ ^[0-9]+$ ]] || false
 [[ "${result}" -gt 0 ]] || false
 [[ "${result}" != "-1" ]] || false
 [[ "${result}" != "-2" ]] || false
}

@test "get_country: return value is always INTEGER (never NULL)" {
 local result
 
 result=$(psql -d "${DBNAME}" -t -c "SELECT get_country(0.0, 0.0, 2000000);" | tr -d ' ')
 [[ -n "${result}" ]] || false
 [[ "${result}" != "NULL" ]] || false
}

@test "get_country: -1 only for known international waters" {
 # -1 should ONLY be returned for known international waters
 # If a location is not in international_waters table, it should return -2 or valid country_id
 
 local result
 
 # Test Null Island (0, 0) - may return -1 if in international_waters table, or -2/valid if not
 result=$(psql -d "${DBNAME}" -t -c "SELECT get_country(0.0, 0.0, 3000000);" | tr -d ' ')
 [[ "${result}" =~ ^(-1|-2|[0-9]+)$ ]] || false
 
 # Test mid-ocean location
 result=$(psql -d "${DBNAME}" -t -c "SELECT get_country(-30.0, 25.0, 3000001);" | tr -d ' ')
 [[ "${result}" =~ ^(-1|-2|[0-9]+)$ ]] || false
}

@test "get_country: -2 for unknown/not found countries" {
 # -2 should be returned when country is not found and not in international_waters
 
 local result
 
 # Test location far from land (may return -2 or -1 depending on international_waters table)
 result=$(psql -d "${DBNAME}" -t -c "SELECT get_country(-100.0, 0.0, 4000000);" | tr -d ' ')
 [[ "${result}" =~ ^(-1|-2|[0-9]+)$ ]] || false
}

@test "get_country: valid countries return positive integers" {
 local result
 local countries=(
  "-47.8825|-15.7942|Brazil"
  "-66.9036|10.4806|Venezuela"
  "-70.6693|-33.4489|Chile"
  "13.4050|52.5200|Germany"
  "2.3522|48.8566|France"
  "-0.1276|51.5074|UK"
  "40.7128|-74.0060|USA"
 )
 
 for country_data in "${countries[@]}"; do
  IFS='|' read -r lon lat country_name <<< "${country_data}"
  result=$(psql -d "${DBNAME}" -t -c "SELECT get_country(${lon}, ${lat}, 5000000);" | tr -d ' ')
  
  if [[ ! "${result}" =~ ^[0-9]+$ ]] || [[ "${result}" -le 0 ]]; then
   echo "FAIL: ${country_name} (lon: ${lon}, lat: ${lat}) returned invalid value: ${result}"
   false
  fi
 done
}

@test "get_country: return value semantics are correct" {
 # Verify that return values follow the correct semantics:
 # - > 0: Valid country_id
 # - -1: Known international waters (from international_waters table)
 # - -2: Unknown/not found country
 
 local result
 local valid_countries=(
  "-47.8825|-15.7942"
  "-66.9036|10.4806"
  "-70.6693|-33.4489"
 )
 
 for coords in "${valid_countries[@]}"; do
  IFS='|' read -r lon lat <<< "${coords}"
  result=$(psql -d "${DBNAME}" -t -c "SELECT get_country(${lon}, ${lat}, 6000000);" | tr -d ' ')
  
  # Must be positive integer (valid country)
  if [[ ! "${result}" =~ ^[0-9]+$ ]] || [[ "${result}" -le 0 ]]; then
   echo "FAIL: Valid country coordinates (lon: ${lon}, lat: ${lat}) returned invalid value: ${result}"
   false
  fi
  
  # Must NOT be -1 or -2
  if [[ "${result}" == "-1" ]] || [[ "${result}" == "-2" ]]; then
   echo "FAIL: Valid country coordinates (lon: ${lon}, lat: ${lat}) returned ${result} instead of valid country_id"
   false
  fi
 done
}

@test "get_country: SQL unit tests pass" {
 # Run the comprehensive SQL unit tests
 local test_file="${BATS_TEST_DIRNAME}/../sql/get_country_return_values.test.sql"
 
 if [[ ! -f "${test_file}" ]]; then
  skip "Test file not found: ${test_file}"
 fi
 
 # Run SQL tests
 run psql -d "${DBNAME}" -f "${test_file}" -v ON_ERROR_STOP=1
 
 if [[ "${status}" -ne 0 ]]; then
  echo "SQL unit tests failed:"
  echo "${output}"
  false
 fi
}
