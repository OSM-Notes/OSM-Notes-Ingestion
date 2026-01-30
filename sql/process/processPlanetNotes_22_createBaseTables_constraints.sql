-- Create constraints in base tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

-- Users table already has PRIMARY KEY defined in CREATE TABLE
-- ALTER TABLE users
--  ADD CONSTRAINT pk_users
--  PRIMARY KEY (user_id);

ALTER TABLE notes
 ADD CONSTRAINT pk_notes
 PRIMARY KEY (note_id);

-- The API does not provide an identifier for the comments, therefore, this
-- project implemented another column for the id. However, the execution cannot
-- be parallelized. With the sequence, the order the comments were inserted can
-- be identified.
ALTER TABLE note_comments
 ADD CONSTRAINT pk_note_comments
 PRIMARY KEY (id);

ALTER TABLE note_comments_text
 ADD CONSTRAINT pk_text_comments
 PRIMARY KEY (id);

ALTER TABLE note_comments
 ADD CONSTRAINT fk_notes
 FOREIGN KEY (note_id)
 REFERENCES notes (note_id);

ALTER TABLE note_comments
 ADD CONSTRAINT fk_users
 FOREIGN KEY (id_user)
 REFERENCES users (user_id);

-- Index: usernames
-- Benefits: API (userService.ts - user lookups), Analytics (datamartUsers - user analysis)
-- Used by: Queries filtering/joining users by username
CREATE INDEX IF NOT EXISTS usernames ON users (username);
COMMENT ON INDEX usernames IS 'To query by username. Used by: API userService, Analytics datamartUsers';

-- Index: notes_closed (closed_at)
-- Benefits: WMS (prepareDatabase.sql:100 - extracts year_closed_at), API (noteService.ts:243 - filters by closed_at),
--           Analytics (Staging_34_initialFactsLoadCreate.sql - JOINs with notes, exportClosedNotesByCountry.sql - filters closed notes),
--           Ingestion (deleteDataAfterTimestamp.sql:66 - deletes by closed_at, notesCheckVerifier-report.sql:129 - compares notes)
-- Used by: Queries filtering notes by closure time, WMS layer for closed notes
CREATE INDEX IF NOT EXISTS notes_closed ON notes (closed_at);
COMMENT ON INDEX notes_closed IS 'To query by closed time. Used by: WMS (closed notes layer), API (search filters), Analytics (ETL staging), Ingestion (cleanup, verification)';

-- Index: notes_created (created_at DESC)
-- Benefits: WMS (prepareDatabase.sql:100 - extracts year_created_at, notes_open index on year_created_at),
--           API (noteService.ts:209-218 - date range filters, :251 - ORDER BY created_at DESC),
--           Analytics (Staging_34_initialFactsLoadCreate.sql:74,94 - JOINs, Staging_34a - year filters),
--           Ingestion (deleteDataAfterTimestamp.sql:64 - deletes by created_at, notesCheckVerifier-report.sql:117 - compares notes)
-- Used by: Queries filtering/ordering notes by creation time, WMS layer for open notes, API pagination
-- Note: DESC order optimizes ORDER BY created_at DESC (very common in API pagination)
CREATE INDEX IF NOT EXISTS notes_created ON notes (created_at DESC);
COMMENT ON INDEX notes_created IS 'To query by opening time. DESC order optimizes ORDER BY created_at DESC (common in API pagination). Used by: WMS (open notes layer), API (date filters, pagination ORDER BY), Analytics (ETL staging by date), Ingestion (cleanup, verification)';

-- Index: notes_countries (id_country)
-- Benefits: WMS (prepareDatabase.sql:102 - calculates country_shape_mod),
--           API (noteService.ts:191-194 - filters by country, analyze_queries.sql:145 - performance analysis),
--           Analytics (Staging_34_initialFactsLoadCreate.sql:74,94 - JOINs, exportClosedNotesByCountry.sql - exports by country, datamartCountries),
--           Ingestion (functionsProcess_35_assignCountryToNotesChunk.sql - country assignment, functionsProcess_37 - reassignment)
-- Used by: Queries filtering/grouping notes by country, country-based analytics
CREATE INDEX IF NOT EXISTS notes_countries ON notes (id_country);
COMMENT ON INDEX notes_countries IS 'To query by location of the note. Used by: WMS (country-based styling), API (country filters), Analytics (country datamarts, exports), Ingestion (country assignment)';

-- Index: notes_country_note_id (id_country, note_id) - Partial Index
-- Benefits: Ingestion (functionsProcess_33_verifyNoteIntegrity.sql:61 - integrity verification with id_country IS NOT NULL + note_id range),
--           Analytics (integrity checks by country and note_id range), API (queries filtering by country and ordering by note_id)
-- Used by: Integrity verification queries, country-based note_id range queries
CREATE INDEX IF NOT EXISTS notes_country_note_id ON notes (id_country, note_id)
  WHERE id_country IS NOT NULL;
COMMENT ON INDEX notes_country_note_id IS 'Composite index for integrity verification queries (id_country IS NOT NULL + note_id range). Used by: Ingestion (verifyNoteIntegrity), Analytics (integrity checks), API (country+note_id filters)';

-- Index: notes_spatial (longitude, latitude) - GIST Spatial Index
-- Benefits: WMS (prepareDatabase.sql:107 - creates geometry ST_SetSRID(ST_MakePoint(...)) for map visualization),
--           API (noteService.ts:222-230 - bounding box filters: longitude/latitude ranges),
--           Analytics (geographic analysis and regional groupings),
--           Ingestion (functionsProcess_20_createFunctionToGetCountry.sql - get_country() function uses coordinates for country assignment,
--                     processAPINotes_31_insertNewNotesAndComments.sql:133 - country lookup by coordinates)
-- Used by: Spatial queries, geographic proximity searches, country assignment by coordinates, map visualizations
CREATE INDEX IF NOT EXISTS notes_spatial ON notes
  USING GIST (ST_Point(longitude, latitude));
COMMENT ON INDEX notes_spatial IS 'Spatial index for geographic queries. Used by: WMS (map visualization), API (bounding box filters), Analytics (geographic analysis), Ingestion (get_country() coordinate lookup)';

-- Index: note_comments_id (note_id)
-- Benefits: API (noteService.ts:69,248 - LEFT JOIN note_comments ON note_id, :138 - filters comments by note_id),
--           Analytics (Staging_34_initialFactsLoadCreate.sql:77-79 - JOIN note_comments c ON c.note_id = n.note_id,
--                     Staging_35a_initialFactsLoadExecute_Simple.sql:53 - JOINs with note_comments),
--           Ingestion (deleteDataAfterTimestamp.sql:52-56 - deletes comments by note_id)
-- Used by: JOINs between notes and comments, queries getting all comments for a note
CREATE INDEX IF NOT EXISTS note_comments_id ON note_comments (note_id);
COMMENT ON INDEX note_comments_id IS 'To query by the associated note. Used by: API (getNoteComments, searchNotes JOINs), Analytics (ETL staging JOINs), Ingestion (cleanup by note_id)';

-- Index: note_comments_users (id_user)
-- Benefits: Analytics (datamartUsers - user activity analysis, grouping comments by user),
--           API (userService.ts - user-related queries)
-- Used by: Queries grouping/filtering comments by user, user activity analysis
CREATE INDEX IF NOT EXISTS note_comments_users ON note_comments (id_user);
COMMENT ON INDEX note_comments_users IS 'To query by the user who performed the action. Used by: Analytics (datamartUsers, user activity), API (userService)';

-- Index: note_comments_created (created_at)
-- Benefits: API (noteService.ts:139 - ORDER BY nc.created_at ASC),
--           Analytics (Staging_34_initialFactsLoadCreate.sql:86-87 - filters by date: WHERE c.created_at >= max_processed_timestamp,
--                     Staging_34a_initialFactsLoadCreate_Parallel.sql:64 - year filters: EXTRACT(YEAR FROM c.created_at)),
--           Ingestion (deleteDataAfterTimestamp.sql:50-51 - deletes comments by date)
-- Used by: Queries filtering/ordering comments by creation time, incremental ETL processing
CREATE INDEX IF NOT EXISTS note_comments_created ON note_comments (created_at);
COMMENT ON INDEX note_comments_created IS 'To query by the time of the action. Used by: API (ORDER BY created_at), Analytics (ETL staging date filters, incremental processing), Ingestion (cleanup by date)';

-- Index: note_comments_id_event (note_id, event)
-- Benefits: Analytics (Staging_34_initialFactsLoadCreate.sql:80-82 - JOIN filtering by event: o.event = ''opened'',
--                     Staging_35a_initialFactsLoadExecute_Simple.sql:57-61 - similar JOIN with event filter),
--           Ingestion (queries finding specific comment types: opened, closed, commented, etc.)
-- Used by: Queries filtering comments by note_id and event type, ETL staging finding opening comments
CREATE INDEX IF NOT EXISTS note_comments_id_event ON note_comments (note_id, event);
COMMENT ON INDEX note_comments_id_event IS 'To query by the id and event. Used by: Analytics (ETL staging - finding opened comments), Ingestion (event-type queries)';

-- Index: note_comments_id_created (note_id, created_at)
-- Benefits: API (noteService.ts:138-139 - WHERE nc.note_id = $1 ORDER BY nc.created_at ASC),
--           Analytics (Staging_34_initialFactsLoadCreate.sql:88 - ORDER BY c.note_id, c.id),
--           Ingestion (queries getting comments for a note ordered chronologically)
-- Used by: Queries getting comments for a note ordered by creation time
CREATE INDEX IF NOT EXISTS note_comments_id_created ON note_comments (note_id, created_at DESC);
COMMENT ON INDEX note_comments_id_created IS 'To query by the id and creation time. DESC order optimizes ORDER BY created_at DESC. Used by: API (getNoteComments - note_id filter + ORDER BY), Analytics (ETL staging ordering), Ingestion (chronological comment queries)';

-- Index: note_comments_id_text (note_id)
-- Benefits: Analytics (Staging_34_initialFactsLoadCreate.sql:83-84 - LEFT JOIN note_comments_text ON note_id and sequence_action,
--                     Staging_35a_initialFactsLoadExecute_Simple.sql:59-60 - similar JOIN),
--           API (noteService.ts:137 - LEFT JOIN note_comments_text ON comment_id)
-- Used by: JOINs between comments and comment texts, ETL staging loading comment text bodies
CREATE INDEX IF NOT EXISTS note_comments_id_text ON note_comments_text (note_id);
COMMENT ON INDEX note_comments_id_text IS 'To query by the note id. Used by: Analytics (ETL staging JOINs with comment texts), API (getNoteComments JOIN)';

-- Index: username_uniq (username) - UNIQUE
-- Benefits: Ingestion (ensures username uniqueness constraint),
--           API (optimizes unique user lookups), Analytics (prevents duplicates in user analysis)
-- Used by: Uniqueness constraint, unique user lookups
CREATE UNIQUE INDEX username_uniq
 ON users
 (username);
COMMENT ON INDEX username_uniq IS 'Username is unique. Used by: Ingestion (uniqueness constraint), API (unique user lookups), Analytics (duplicate prevention)';
