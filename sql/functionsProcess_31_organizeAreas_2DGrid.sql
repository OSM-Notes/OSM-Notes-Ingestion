-- Provides the priority order to search for countries using intelligent 2D
-- grid partitioning.
-- The world is divided into 24 geographic zones based on BOTH longitude and
-- latitude to minimize expensive ST_Contains calls.
--
-- Each zone lists countries in order of note density (highest first), which
-- means most notes will be matched with fewer ST_Contains operations.
--
-- This replaces the old 5-zone vertical-only partitioning with a more
-- intelligent approach.
--
-- Zone boundaries and priorities are based on:
-- 1. Geographic logic (continents, major regions)
-- 2. Note density from OSM statistics
-- 3. Minimizing cross-zone countries
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-19

-- ============================================================================
-- ZONE 1: USA/CANADA (lon: -150 to -60, lat: 30 to 75)
-- High density zone - includes most of USA and Canada
-- ============================================================================

-- More than 200K notes
UPDATE countries SET zone_us_canada = 1
WHERE country_name_en IN ('United States');

-- More than 50K notes
UPDATE countries SET zone_us_canada = 2
WHERE country_name_en IN ('Canada');

-- More than 1K notes
UPDATE countries SET zone_us_canada = 3
WHERE country_name_en IN ('Greenland');

-- Less than 1K notes
UPDATE countries SET zone_us_canada = 4
WHERE country_name_en IN ('France'); -- Saint Pierre and Miquelon

-- Maritimes
UPDATE countries SET zone_us_canada = 10
WHERE country_name_en IN ('United States (EEZ)');

-- ============================================================================
-- ZONE 2: MEXICO/CENTRAL AMERICA (lon: -120 to -75, lat: 5 to 35)
-- ============================================================================

-- More than 20K notes
UPDATE countries SET zone_mexico_central_america = 1
WHERE country_name_en IN ('Mexico');

-- More than 10K notes
UPDATE countries SET zone_mexico_central_america = 2
WHERE country_name_en IN ('Cuba', 'Nicaragua');

-- More than 5K notes
UPDATE countries SET zone_mexico_central_america = 3
WHERE country_name_en IN ('United States');

-- More than 2K notes
UPDATE countries SET zone_mexico_central_america = 4
WHERE country_name_en IN ('Costa Rica', 'Guatemala');

-- More than 1K notes
UPDATE countries SET zone_mexico_central_america = 5
WHERE country_name_en IN ('Panama', 'Honduras', 'El Salvador');

-- Less than 1K notes
UPDATE countries SET zone_mexico_central_america = 6
WHERE country_name_en IN ('Belize');

-- Maritimes
UPDATE countries SET zone_mexico_central_america = 10
WHERE country_name_en IN ('Nicaragua (EEZ)', 'Costa Rica (EEZ)');

-- ============================================================================
-- ZONE 3: CARIBBEAN (lon: -90 to -60, lat: 10 to 30)
-- ============================================================================

-- More than 10K notes
UPDATE countries SET zone_caribbean = 1
WHERE country_name_en IN ('Cuba');

-- More than 5K notes
UPDATE countries SET zone_caribbean = 2
WHERE country_name_en IN ('Haiti');

-- More than 2K notes
UPDATE countries SET zone_caribbean = 3
WHERE country_name_en IN ('Dominican Republic');

-- More than 1K notes
UPDATE countries SET zone_caribbean = 4
WHERE country_name_en IN ('Trinidad and Tobago');

-- Less than 1K notes
UPDATE countries SET zone_caribbean = 5
WHERE country_name_en IN ('Jamaica', 'The Bahamas', 'Saint Lucia',
  'Barbados', 'Saint Vincent and the Grenadines', 'Dominica', 'Grenada',
  'Bermuda', 'Cayman Islands', 'Turks and Caicos Islands',
  'Saint Kitts and Nevis', 'Antigua and Barbuda', 'British Virgin Islands',
  'Anguilla');

-- Maritimes
UPDATE countries SET zone_caribbean = 10
WHERE country_name_en IN ('Guadeloupe (EEZ)');

-- ============================================================================
-- ZONE 4: NORTHERN SOUTH AMERICA (lon: -80 to -35, lat: -15 to 15)
-- Includes Ecuador, Colombia, Venezuela, Brazil (north), Guyana, Suriname
-- ============================================================================

-- More than 50K notes
UPDATE countries SET zone_northern_south_america = 1
WHERE country_name_en IN ('Brazil');

-- More than 20K notes
UPDATE countries SET zone_northern_south_america = 2
WHERE country_name_en IN ('Ecuador');

-- More than 10K notes
UPDATE countries SET zone_northern_south_america = 3
WHERE country_name_en IN ('Peru', 'Colombia', 'Bolivia');

-- More than 5K notes
UPDATE countries SET zone_northern_south_america = 4
WHERE country_name_en IN ('Venezuela');

-- Less than 1K notes
UPDATE countries SET zone_northern_south_america = 5
WHERE country_name_en IN ('Suriname', 'Guyana', 'French Guiana');

-- Maritimes
UPDATE countries SET zone_northern_south_america = 10
WHERE country_name_en IN ('Brazil (EEZ)', 'Colombia (EEZ)',
  'Ecuador (EEZ)');

-- ============================================================================
-- ZONE 5: SOUTHERN SOUTH AMERICA (lon: -75 to -35, lat: -56 to -15)
-- Includes Argentina, Chile, Uruguay, Paraguay, southern Brazil
-- ============================================================================

-- More than 50K notes
UPDATE countries SET zone_southern_south_america = 1
WHERE country_name_en IN ('Brazil');

-- More than 20K notes
UPDATE countries SET zone_southern_south_america = 2
WHERE country_name_en IN ('Argentina');

-- More than 10K notes
UPDATE countries SET zone_southern_south_america = 3
WHERE country_name_en IN ('Chile');

-- More than 5K notes
UPDATE countries SET zone_southern_south_america = 4
WHERE country_name_en IN ('Bolivia');

-- More than 2K notes
UPDATE countries SET zone_southern_south_america = 5
WHERE country_name_en IN ('Uruguay', 'Paraguay');

-- Less than 1K notes
UPDATE countries SET zone_southern_south_america = 6
WHERE country_name_en IN ('Falkland Islands',
  'South Georgia and the South Sandwich Islands');

-- Maritimes
UPDATE countries SET zone_southern_south_america = 10
WHERE country_name_en IN ('Brazil (EEZ)', 'Argentina (EEZ)',
  'Chile (EEZ)', 'Brazil (Contiguous Zone)');

-- ============================================================================
-- ZONE 6: WESTERN EUROPE (lon: -10 to 15, lat: 35 to 60)
-- Highest density zone globally - includes Germany, France, UK, Spain, etc.
-- ============================================================================

-- More than 500K notes
UPDATE countries SET zone_western_europe = 1
WHERE country_name_en IN ('Germany');

-- More than 200K notes
UPDATE countries SET zone_western_europe = 2
WHERE country_name_en IN ('France');

-- More than 100K notes
UPDATE countries SET zone_western_europe = 3
WHERE country_name_en IN ('Spain', 'United Kingdom', 'Italy');

-- More than 50K notes
UPDATE countries SET zone_western_europe = 4
WHERE country_name_en IN ('Netherlands');

-- More than 20K notes
UPDATE countries SET zone_western_europe = 5
WHERE country_name_en IN ('Belgium', 'Austria', 'Switzerland');

-- More than 10K notes
UPDATE countries SET zone_western_europe = 6
WHERE country_name_en IN ('Portugal');

-- More than 2K notes
UPDATE countries SET zone_western_europe = 7
WHERE country_name_en IN ('Luxembourg', 'Monaco', 'Andorra');

-- Less than 1K notes
UPDATE countries SET zone_western_europe = 8
WHERE country_name_en IN ('Liechtenstein', 'Jersey', 'Guernsey',
  'Isle of Man', 'San Marino', 'Vatican City', 'Gibraltar');

-- Maritimes
UPDATE countries SET zone_western_europe = 10
WHERE country_name_en IN ('Spain (EEZ)', 'United Kingdom (EEZ)',
  'Italy (EEZ)', 'Germany (EEZ)', 'France (EEZ) - Mediterranean Sea',
  'Ireland (EEZ)', 'Dutch Exclusive Economic Zone', 'Belgium (EEZ)',
  'France (Contiguous Zone)', 'Contiguous Zone of the Netherlands',
  'France (contiguous area in the Gulf of Biscay and west of English Channel)');

-- ============================================================================
-- ZONE 7: EASTERN EUROPE (lon: 15 to 45, lat: 35 to 60)
-- Includes Poland, Czechia, Hungary, Romania, Ukraine, etc.
-- ============================================================================

-- More than 100K notes
UPDATE countries SET zone_eastern_europe = 1
WHERE country_name_en IN ('Poland');

-- More than 20K notes
UPDATE countries SET zone_eastern_europe = 2
WHERE country_name_en IN ('Czechia', 'Austria', 'Croatia');

-- More than 10K notes
UPDATE countries SET zone_eastern_europe = 3
WHERE country_name_en IN ('Hungary', 'Ukraine', 'Slovakia', 'Greece');

-- More than 5K notes
UPDATE countries SET zone_eastern_europe = 4
WHERE country_name_en IN ('Romania', 'Serbia');

-- More than 2K notes
UPDATE countries SET zone_eastern_europe = 5
WHERE country_name_en IN ('Bosnia and Herzegovina', 'Bulgaria', 'Slovenia',
  'Belarus', 'Kosovo', 'Albania', 'Montenegro');

-- More than 1K notes
UPDATE countries SET zone_eastern_europe = 6
WHERE country_name_en IN ('North Macedonia');

-- Less than 1K notes
UPDATE countries SET zone_eastern_europe = 7
WHERE country_name_en IN ('Moldova', 'San Marino');

-- ============================================================================
-- ZONE 8: NORTHERN EUROPE (lon: -10 to 35, lat: 55 to 75)
-- Includes Scandinavia, Baltic states, northern UK
-- ============================================================================

-- More than 100K notes
UPDATE countries SET zone_northern_europe = 1
WHERE country_name_en IN ('United Kingdom');

-- More than 20K notes
UPDATE countries SET zone_northern_europe = 2
WHERE country_name_en IN ('Sweden');

-- More than 10K notes
UPDATE countries SET zone_northern_europe = 3
WHERE country_name_en IN ('Denmark');

-- More than 5K notes
UPDATE countries SET zone_northern_europe = 4
WHERE country_name_en IN ('Norway', 'Finland', 'Latvia');

-- More than 2K notes
UPDATE countries SET zone_northern_europe = 5
WHERE country_name_en IN ('Iceland', 'Lithuania', 'Estonia');

-- Less than 1K notes
UPDATE countries SET zone_northern_europe = 6
WHERE country_name_en IN ('Faroe Islands', 'Greenland');

-- Maritimes
UPDATE countries SET zone_northern_europe = 10
WHERE country_name_en IN ('Norway (EEZ)', 'Denmark (EEZ)', 'Sweden (EEZ)',
  'Iceland (EEZ)', 'Fisheries protection zone around Jan Mayen',
  'Fishing territory around the Faroe Islands',
  'Fisheries protection zone around Svalbard');

-- ============================================================================
-- ZONE 9: SOUTHERN EUROPE (lon: -10 to 30, lat: 30 to 50)
-- Includes Italy, Greece, Balkans, Turkey (west)
-- ============================================================================

-- More than 100K notes
UPDATE countries SET zone_southern_europe = 1
WHERE country_name_en IN ('Italy', 'Spain');

-- More than 20K notes
UPDATE countries SET zone_southern_europe = 2
WHERE country_name_en IN ('Croatia');

-- More than 10K notes
UPDATE countries SET zone_southern_europe = 3
WHERE country_name_en IN ('Greece', 'Portugal');

-- More than 5K notes
UPDATE countries SET zone_southern_europe = 4
WHERE country_name_en IN ('Serbia');

-- More than 2K notes
UPDATE countries SET zone_southern_europe = 5
WHERE country_name_en IN ('Bosnia and Herzegovina', 'Bulgaria', 'Slovenia',
  'Kosovo', 'Albania', 'Montenegro');

-- More than 1K notes
UPDATE countries SET zone_southern_europe = 6
WHERE country_name_en IN ('North Macedonia');

-- Less than 1K notes
UPDATE countries SET zone_southern_europe = 7
WHERE country_name_en IN ('Malta', 'Cyprus');

-- ============================================================================
-- ZONE 10: NORTHERN AFRICA (lon: -20 to 50, lat: 15 to 40)
-- Includes Morocco, Algeria, Tunisia, Libya, Egypt, etc.
-- ============================================================================

-- More than 10K notes
UPDATE countries SET zone_northern_africa = 1
WHERE country_name_en IN ('Algeria');

-- More than 2K notes
UPDATE countries SET zone_northern_africa = 2
WHERE country_name_en IN ('Morocco', 'Libya', 'Tunisia');

-- More than 1K notes
UPDATE countries SET zone_northern_africa = 3
WHERE country_name_en IN ('Egypt');

-- Less than 1K notes
UPDATE countries SET zone_northern_africa = 4
WHERE country_name_en IN ('Mauritania', 'Cape Verde', 'Sudan',
  'Sahrawi Arab Democratic Republic');

-- ============================================================================
-- ZONE 11: WESTERN AFRICA (lon: -20 to 20, lat: -10 to 20)
-- Includes Nigeria, Ghana, Côte d'Ivoire, DRC, etc.
-- ============================================================================

-- More than 10K notes
UPDATE countries SET zone_western_africa = 1
WHERE country_name_en IN ('Côte d''Ivoire');

-- More than 2K notes
UPDATE countries SET zone_western_africa = 2
WHERE country_name_en IN ('Democratic Republic of the Congo', 'Ghana');

-- More than 1K notes
UPDATE countries SET zone_western_africa = 3
WHERE country_name_en IN ('Nigeria', 'Togo', 'Cameroon', 'Burkina Faso',
  'Senegal', 'Mali');

-- Less than 1K notes
UPDATE countries SET zone_western_africa = 4
WHERE country_name_en IN ('Benin', 'Niger', 'Guinea', 'Sierra Leone',
  'Congo-Brazzaville', 'Chad', 'Central African Republic', 'Guinea-Bissau',
  'Liberia', 'The Gambia', 'Gabon', 'Equatorial Guinea',
  'São Tomé and Príncipe');

-- ============================================================================
-- ZONE 12: EASTERN AFRICA (lon: 20 to 55, lat: -15 to 20)
-- Includes Ethiopia, Kenya, Tanzania, Uganda, etc.
-- ============================================================================

-- More than 2K notes
UPDATE countries SET zone_eastern_africa = 1
WHERE country_name_en IN ('Tanzania', 'Ethiopia', 'Uganda');

-- More than 1K notes
UPDATE countries SET zone_eastern_africa = 2
WHERE country_name_en IN ('Kenya', 'Madagascar', 'Zimbabwe');

-- Less than 1K notes
UPDATE countries SET zone_eastern_africa = 3
WHERE country_name_en IN ('Sudan', 'Somalia', 'Mozambique', 'Zambia',
  'Mauritius', 'Rwanda', 'Malawi', 'Seychelles', 'South Sudan', 'Burundi',
  'Eritrea', 'Djibouti', 'Comoros');

-- Maritimes
UPDATE countries SET zone_eastern_africa = 10
WHERE country_name_en IN ('France - La Réunion - Tromelin Island (EEZ)');

-- ============================================================================
-- ZONE 13: SOUTHERN AFRICA (lon: 10 to 50, lat: -36 to -15)
-- Includes South Africa, Namibia, Botswana, etc.
-- ============================================================================

-- More than 2K notes
UPDATE countries SET zone_southern_africa = 1
WHERE country_name_en IN ('South Africa');

-- More than 1K notes
UPDATE countries SET zone_southern_africa = 2
WHERE country_name_en IN ('Namibia', 'Zimbabwe');

-- Less than 1K notes
UPDATE countries SET zone_southern_africa = 3
WHERE country_name_en IN ('Botswana', 'Zambia', 'Mozambique', 'Lesotho',
  'Eswatini', 'Madagascar');

-- Maritimes
UPDATE countries SET zone_southern_africa = 10
WHERE country_name_en IN ('South Africa (EEZ)',
  'South Georgia and the South Sandwich Islands');

-- ============================================================================
-- ZONE 14: MIDDLE EAST (lon: 25 to 65, lat: 10 to 45)
-- Includes Turkey, Iran, Iraq, Saudi Arabia, Israel, etc.
-- ============================================================================

-- More than 50K notes
UPDATE countries SET zone_middle_east = 1
WHERE country_name_en IN ('Iran', 'Turkey');

-- More than 20K notes
UPDATE countries SET zone_middle_east = 2
WHERE country_name_en IN ('Iraq');

-- More than 5K notes
UPDATE countries SET zone_middle_east = 3
WHERE country_name_en IN ('Saudi Arabia', 'Egypt', 'Israel');

-- More than 2K notes
UPDATE countries SET zone_middle_east = 4
WHERE country_name_en IN ('United Arab Emirates', 'Cyprus', 'Yemen',
  'Syria', 'Jordan');

-- More than 1K notes
UPDATE countries SET zone_middle_east = 5
WHERE country_name_en IN ('Oman', 'Lebanon');

-- Less than 1K notes
UPDATE countries SET zone_middle_east = 6
WHERE country_name_en IN ('Kuwait', 'Qatar', 'Bahrain', 'Gaza Strip',
  'Palestinian Territories');

-- Maritimes
UPDATE countries SET zone_middle_east = 10
WHERE country_name_en IN ('British Sovereign Base Areas');

-- ============================================================================
-- ZONE 15: RUSSIA NORTH (lon: 25 to 180, lat: 55 to 80)
-- Northern Russia and Siberia
-- ============================================================================

-- More than 200K notes
UPDATE countries SET zone_russia_north = 1
WHERE country_name_en IN ('Russia');

-- More than 5K notes
UPDATE countries SET zone_russia_north = 2
WHERE country_name_en IN ('Finland');

-- More than 2K notes
UPDATE countries SET zone_russia_north = 3
WHERE country_name_en IN ('Belarus', 'Latvia', 'Lithuania', 'Estonia');

-- Less than 1K notes
UPDATE countries SET zone_russia_north = 4
WHERE country_name_en IN ('Norway');

-- Maritimes
UPDATE countries SET zone_russia_north = 10
WHERE country_name_en IN ('Russia (EEZ)', 'NEAFC (EEZ)');

-- ============================================================================
-- ZONE 16: RUSSIA SOUTH (lon: 30 to 150, lat: 40 to 60)
-- Southern Russia, Kazakhstan
-- ============================================================================

-- More than 200K notes
UPDATE countries SET zone_russia_south = 1
WHERE country_name_en IN ('Russia');

-- More than 50K notes
UPDATE countries SET zone_russia_south = 2
WHERE country_name_en IN ('Ukraine');

-- More than 20K notes
UPDATE countries SET zone_russia_south = 3
WHERE country_name_en IN ('Belarus');

-- More than 5K notes
UPDATE countries SET zone_russia_south = 4
WHERE country_name_en IN ('Romania', 'Georgia', 'Armenia', 'Moldova',
  'Azerbaijan');

-- More than 2K notes
UPDATE countries SET zone_russia_south = 5
WHERE country_name_en IN ('Kazakhstan', 'Bulgaria');

-- More than 1K notes
UPDATE countries SET zone_russia_south = 6
WHERE country_name_en IN ('Lithuania', 'Latvia');

-- Less than 1K notes
UPDATE countries SET zone_russia_south = 7
WHERE country_name_en IN ('Estonia');

-- ============================================================================
-- ZONE 17: CENTRAL ASIA (lon: 45 to 90, lat: 30 to 55)
-- Includes Kazakhstan, Uzbekistan, Turkmenistan, Kyrgyzstan, Tajikistan
-- ============================================================================

-- More than 5K notes
UPDATE countries SET zone_central_asia = 1
WHERE country_name_en IN ('Kazakhstan', 'Uzbekistan');

-- More than 2K notes
UPDATE countries SET zone_central_asia = 2
WHERE country_name_en IN ('Kyrgyzstan', 'Tajikistan');

-- More than 1K notes
UPDATE countries SET zone_central_asia = 3
WHERE country_name_en IN ('Turkmenistan');

-- Less than 1K notes
UPDATE countries SET zone_central_asia = 4
WHERE country_name_en IN ('Afghanistan');

-- ============================================================================
-- ZONE 18: INDIA/SOUTH ASIA (lon: 60 to 95, lat: 5 to 40)
-- Includes India, Pakistan, Bangladesh, Nepal, Sri Lanka
-- ============================================================================

-- More than 20K notes
UPDATE countries SET zone_india_south_asia = 1
WHERE country_name_en IN ('India');

-- More than 5K notes
UPDATE countries SET zone_india_south_asia = 2
WHERE country_name_en IN ('Nepal', 'Pakistan');

-- More than 2K notes
UPDATE countries SET zone_india_south_asia = 3
WHERE country_name_en IN ('Sri Lanka', 'Bangladesh');

-- Less than 1K notes
UPDATE countries SET zone_india_south_asia = 4
WHERE country_name_en IN ('Maldives', 'Bhutan', 'Afghanistan');

-- Maritimes
UPDATE countries SET zone_india_south_asia = 10
WHERE country_name_en IN ('British Indian Ocean Territory');

-- ============================================================================
-- ZONE 19: SOUTHEAST ASIA (lon: 95 to 140, lat: -12 to 25)
-- Includes Thailand, Vietnam, Indonesia, Philippines, Malaysia, Myanmar
-- ============================================================================

-- More than 20K notes
UPDATE countries SET zone_southeast_asia = 1
WHERE country_name_en IN ('Philippines', 'Indonesia');

-- More than 10K notes
UPDATE countries SET zone_southeast_asia = 2
WHERE country_name_en IN ('Thailand', 'Vietnam', 'Malaysia');

-- More than 5K notes
UPDATE countries SET zone_southeast_asia = 3
WHERE country_name_en IN ('Myanmar');

-- More than 2K notes
UPDATE countries SET zone_southeast_asia = 4
WHERE country_name_en IN ('Cambodia', 'Singapore', 'Laos');

-- Less than 1K notes
UPDATE countries SET zone_southeast_asia = 5
WHERE country_name_en IN ('East Timor', 'Papua New Guinea', 'Brunei');

-- Maritimes
UPDATE countries SET zone_southeast_asia = 10
WHERE country_name_en IN ('Philippine (EEZ)', 'New Caledonia (EEZ)');

-- ============================================================================
-- ZONE 20: EASTERN ASIA (lon: 100 to 145, lat: 20 to 55)
-- Includes China, Japan, Korea, Taiwan, Mongolia
-- ============================================================================

-- More than 20K notes
UPDATE countries SET zone_eastern_asia = 1
WHERE country_name_en IN ('China', 'Japan', 'Taiwan');

-- More than 10K notes
UPDATE countries SET zone_eastern_asia = 2
WHERE country_name_en IN ('South Korea');

-- More than 1K notes
UPDATE countries SET zone_eastern_asia = 3
WHERE country_name_en IN ('Mongolia');

-- Less than 1K notes
UPDATE countries SET zone_eastern_asia = 4
WHERE country_name_en IN ('North Korea');

-- ============================================================================
-- ZONE 21: AUSTRALIA/NZ (lon: 110 to 180, lat: -50 to -10)
-- ============================================================================

-- More than 20K notes
UPDATE countries SET zone_australia_nz = 1
WHERE country_name_en IN ('Australia');

-- More than 5K notes
UPDATE countries SET zone_australia_nz = 2
WHERE country_name_en IN ('New Zealand');

-- Less than 1K notes
UPDATE countries SET zone_australia_nz = 3
WHERE country_name_en IN ('Papua New Guinea');

-- Maritimes
UPDATE countries SET zone_australia_nz = 10
WHERE country_name_en IN ('Australia (EEZ)', 'New Zealand (EEZ)',
  'New Zealand (Contiguous Zone)');

-- ============================================================================
-- ZONE 22: PACIFIC ISLANDS (lon: 130 to -120 [wraps], lat: -30 to 30)
-- Includes Fiji, Tonga, Samoa, Kiribati, French Polynesia, etc.
-- ============================================================================

-- More than 5K notes
UPDATE countries SET zone_pacific_islands = 1
WHERE country_name_en IN ('New Zealand');

-- Less than 1K notes
UPDATE countries SET zone_pacific_islands = 2
WHERE country_name_en IN ('Tonga', 'Cook Islands', 'Samoa', 'Fiji',
  'Pitcairn Islands', 'Kiribati', 'Niue', 'French Polynesia');

-- Less than 500 notes
UPDATE countries SET zone_pacific_islands = 3
WHERE country_name_en IN ('Vanuatu', 'Solomon Islands', 'Palau',
  'Federated States of Micronesia', 'Marshall Islands', 'Tuvalu', 'Nauru',
  'United States');

-- Maritimes
UPDATE countries SET zone_pacific_islands = 10
WHERE country_name_en IN ('French Polynesia (EEZ)');

-- ============================================================================
-- ZONE 23: ARCTIC (all lon, lat > 70)
-- Includes northern territories
-- ============================================================================

-- More than 1K notes
UPDATE countries SET zone_arctic = 1
WHERE country_name_en IN ('Greenland');

-- Less than 1K notes
UPDATE countries SET zone_arctic = 2
WHERE country_name_en IN ('Norway', 'Russia', 'Canada', 'Iceland',
  'Finland', 'Sweden', 'United States');

-- Maritimes
UPDATE countries SET zone_arctic = 10
WHERE country_name_en IN ('Fisheries protection zone around Jan Mayen',
  'Fisheries protection zone around Svalbard', 'NEAFC (EEZ)');

-- ============================================================================
-- ZONE 24: ANTARCTIC (all lon, lat < -60)
-- ============================================================================

-- Less than 500 notes
UPDATE countries SET zone_antarctic = 1
WHERE country_name_en IN ('Falkland Islands',
  'South Georgia and the South Sandwich Islands');

-- Maritimes
UPDATE countries SET zone_antarctic = 10
WHERE country_name_en IN (
  'South Georgia and the South Sandwich Islands');


