-- Provides the order to look for a country according to a basic position of
-- the note.
-- The World is divided in 5 vertical areas, and each area has list of
-- countries:
-- * Americas.
-- * Europe (And Africa).
-- * Russia and middle East.
-- * Asia and Oceania.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25

-- More than 200K
UPDATE countries SET americas = 1 WHERE country_name_en IN ('United States');
-- More than 50K
UPDATE countries SET americas = 2 WHERE country_name_en IN ('Brazil',
  'Canada');
-- More than 20K
UPDATE countries SET americas = 3 WHERE country_name_en IN ('Argentina',
  'Mexico', 'Ecuador');
-- More than 10K
UPDATE countries SET americas = 4 WHERE country_name_en IN ('Peru',
  'Colombia', 'Chile', 'Cuba', 'Nicaragua', 'Bolivia');
-- More than 5K
UPDATE countries SET americas = 5 WHERE country_name_en IN ('Venezuela',
  'Haiti');
-- More than 2K
UPDATE countries SET americas = 6 WHERE country_name_en IN ('Costa Rica',
  'Guatemala', 'France', 'Dominican Republic', 'Uruguay', 'Paraguay');
-- More than 1K
UPDATE countries SET americas = 7 WHERE country_name_en IN (
  'Trinidad and Tobago', 'Panama', 'Honduras', 'El Salvador', 'Netherlands');
-- Less than 1K
UPDATE countries SET americas = 8 WHERE country_name_en IN ('Jamaica');
-- Less than 500
UPDATE countries SET americas = 9 WHERE country_name_en IN ('Greenland',
  'Suriname', 'Guyana', 'Belize', 'The Bahamas', 'Falkland Islands',
  'Saint Lucia', 'Barbados', 'Saint Vincent and the Grenadines', 'Tonga',
  'Cook Islands', 'Dominica', 'Grenada', 'Samoa', 'Bermuda',
  'Cayman Islands', 'Turks and Caicos Islands',
  'South Georgia and the South Sandwich Islands', 'Saint Kitts and Nevis',
  'Antigua and Barbuda', 'Russia', 'Portugal', 'British Virgin Islands',
  'New Zealand', 'Anguilla', 'Fiji', 'Pitcairn Islands', 'Montserrat',
  'Kiribati', 'Niue', 'British Overseas Territories', 'French Polynesia',
  'French Guiana', 'Aruba'
  );
-- Maritimes areas
UPDATE countries SET americas = 10 WHERE country_name_en IN ('Brazil (EEZ)',
  'Chile (EEZ)', 'Brazil (Contiguous Zone)', 'United States (EEZ)',
  'Colombia (EEZ)', 'Ecuador (EEZ)', 'Argentina (EEZ)', 'Guadeloupe (EEZ)',
  'Nicaragua (EEZ)', 'French Polynesia (EEZ)',
  'Contiguous Zone of the Netherlands', 'Costa Rica (EEZ)',
  'New Zealand (EEZ)');

-- More than 500K
UPDATE countries SET europe = 1 WHERE country_name_en IN ('Germany');
-- More than 200K
UPDATE countries SET europe = 2 WHERE country_name_en IN ('France');
-- More than 100K
UPDATE countries SET europe = 3 WHERE country_name_en IN ('Spain',
  'United Kingdom', 'Italy', 'Poland');
-- More than 50K
UPDATE countries SET europe = 4 WHERE country_name_en IN ('Netherlands');
-- More than 20K
UPDATE countries SET europe = 5 WHERE country_name_en IN ('Belgium',
  'Austria', 'Switzerland', 'Croatia', 'Sweden', 'Czechia');
-- More than 10K
UPDATE countries SET europe = 6 WHERE country_name_en IN ('Greece',
  'Ireland', 'Hungary','Ukraine', 'Portugal', 'Slovakia', 'Denmark',
  'Côte d''Ivoire', 'Algeria');
-- More than 5K
UPDATE countries SET europe = 7 WHERE country_name_en IN ('Norway',
  'Finland', 'Romania', 'Serbia', 'Libya', 'Latvia'
  );
-- More than 2K
UPDATE countries SET europe = 8 WHERE country_name_en IN ('Morocco',
  'Democratic Republic of the Congo', 'Bosnia and Herzegovina', 'Bulgaria',
  'Ghana', 'Slovenia', 'Belarus', 'Kosovo', 'Iceland', 'Lithuania', 'Albania',
  'Russia', 'South Africa', 'Estonia', 'Montenegro', 'Luxembourg', 'Angola',
  'Tunisia');
-- More than 1K
UPDATE countries SET europe = 9 WHERE country_name_en IN ('Nigeria',
  'Togo', 'North Macedonia', 'Jersey', 'Cameroon', 'Burkina Faso',
  'Namibia', 'Senegal', 'Mali');
-- Less than 1K
UPDATE countries SET europe = 10 WHERE country_name_en IN ('Malta', 'Benin',
  'Niger', 'Guinea');
-- Less than 500
UPDATE countries SET europe = 11 WHERE country_name_en IN ('Sierra Leone',
  'Mauritania', 'Congo-Brazzaville', 'Chad', 'Cape Verde', 'Botswana',
  'Andorra', 'Guernsey', 'Isle of Man', 'Central African Republic',
  'Faroe Islands', 'Guinea-Bissau', 'Liberia', 'The Gambia', 'San Marino',
  'Gabon', 'Liechtenstein', 'Gibraltar', 'Monaco', 'Equatorial Guinea',
  'Sahrawi Arab Democratic Republic', 'Vatican City', 'Zambia',
  'São Tomé and Príncipe', 'Greenland',
  'Saint Helena, Ascension and Tristan da Cunha',
  'Sudan', 'Brazil');
-- Maritimes areas
UPDATE countries SET europe = 12 WHERE country_name_en IN ('Spain (EEZ)',
  'United Kingdom (EEZ)', 'Italy (EEZ)', 'Germany (EEZ)', 'Norway (EEZ)',
  'France (EEZ) - Mediterranean Sea', 'Denmark (EEZ)', 'Ireland (EEZ)',
  'Dutch Exclusive Economic Zone', 'Sweden (EEZ)',
  'Contiguous Zone of the Netherlands', 'France (Contiguous Zone)',
  'South Africa (EEZ)', 'Brazil (EEZ)', 'Belgium (EEZ)', 'Poland (EEZ)',
  'Russia (EEZ)', 'Iceland (EEZ)',
  'Fisheries protection zone around Jan Mayen',
  'South Georgia and the South Sandwich Islands',
  'Fishing territory around the Faroe Islands',
  'France (contiguous area in the Gulf of Biscay and west of English Channel)');

-- More than 200K
UPDATE countries SET russia_middle_east = 1 WHERE country_name_en IN (
  'Russia');
-- More than 50K
UPDATE countries SET russia_middle_east = 2 WHERE country_name_en IN ('Iran',
  'Ukraine');
-- More than 20K
UPDATE countries SET russia_middle_east = 3 WHERE country_name_en IN (
  'Iraq', 'Belarus', 'Turkey');
-- More than 10K
UPDATE countries SET russia_middle_east = 4 WHERE country_name_en IN ('');
-- More than 5K
UPDATE countries SET russia_middle_east = 5 WHERE country_name_en IN (
  'Romania', 'Saudi Arabia', 'Georgia', 'Armenia', 'Egypt', 'Israel',
  'Finland', 'Azerbaijan', 'Democratic Republic of the Congo', 'Moldova'
  );
-- More than 2K
UPDATE countries SET russia_middle_east = 6 WHERE country_name_en IN (
  'United Arab Emirates', 'Cyprus', 'South Africa', 'Tanzania', 'Yemen',
  'Kazakhstan', 'Greece', 'Syria', 'Uganda', 'France', 'Ethiopia',
  'Bulgaria', 'Jordan');
-- More than 1K
UPDATE countries SET russia_middle_east = 7 WHERE country_name_en IN (
  'Uzbekistan', 'Lithuania', 'Oman', 'Turkmenistan', 'Kenya', 'Lebanon',
  'Madagascar', 'Latvia', 'Zimbabwe');
-- Less than 1K
UPDATE countries SET russia_middle_east = 8 WHERE country_name_en IN (
  'Estonia', 'Sudan', 'Kuwait', 'Somalia', 'Mozambique', 'Qatar', 'Zambia',
  'Mauritius');
-- Less than 500
UPDATE countries SET russia_middle_east = 9 WHERE country_name_en IN (
  'Botswana', 'Rwanda', 'Bahrain', 'Malawi', 'Seychelles', 'South Sudan',
  'Lesotho', 'Burundi', 'Eritrea', 'Norway', 'Djibouti', 'Afghanistan',
  'Comoros', 'Eswatini', 'Central African Republic', 'Pakistan',
  'Libya', 'Namibia', 'Gaza Strip');
-- Maritimes areas
UPDATE countries SET russia_middle_east = 10 WHERE country_name_en IN (
  'British Sovereign Base Areas', 'Fisheries protection zone around Svalbard',
  'NEAFC (EEZ)', 'South Africa (EEZ)', 'Palestinian Territories',
  'France - La Réunion - Tromelin Island (EEZ)');

-- More than 20K
UPDATE countries SET asia_oceania = 1 WHERE country_name_en IN ('Australia',
  'India', 'Russia', 'China', 'Philippines', 'Japan', 'Taiwan',
  'Indonesia');
-- More than 10K
UPDATE countries SET asia_oceania = 2 WHERE country_name_en IN ('Thailand',
  'South Korea', 'Vietnam', 'Malaysia');
-- More than 5K
UPDATE countries SET asia_oceania = 3 WHERE country_name_en IN ('New Zealand',
  'Kazakhstan', 'Uzbekistan', 'Myanmar', 'Nepal', 'Pakistan');
-- More than 2K
UPDATE countries SET asia_oceania = 4 WHERE country_name_en IN ('Kyrgyzstan',
  'Cambodia', 'Sri Lanka', 'Bangladesh', 'Laos', 'Singapore',
  'Tajikistan');
-- More than 1K
UPDATE countries SET asia_oceania = 5 WHERE country_name_en IN ('Mongolia');
-- Less than 1K
UPDATE countries SET asia_oceania = 6 WHERE country_name_en IN ('France',
  'Afghanistan');
-- Less than 500
UPDATE countries SET asia_oceania = 7 WHERE country_name_en IN ('Maldives',
  'Bhutan', 'Vanuatu', 'East Timor', 'Fiji', 'Papua New Guinea',
  'United States', 'North Korea', 'Brunei', 'Solomon Islands', 'Palau',
  'Federated States of Micronesia', 'Marshall Islands', 'Kiribati',
  'Turkmenistan', 'Tuvalu', 'Nauru');
-- Maritimes areas
UPDATE countries SET asia_oceania = 8 WHERE country_name_en IN (
  'Philippine (EEZ)', 'Australia (EEZ)', 'British Indian Ocean Territory',
  'New Caledonia (EEZ)', 'New Zealand (EEZ)',
  'New Zealand (Contiguous Zone)');
