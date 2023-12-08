#!/bin/bash

-- API notes tester. It creates mock notes in the local database:
-- * Id bigger than 7 000 000.
-- * Position 4/72
-- * Created on 2 000
-- * Userid bigger than 20 000 000
-- * User testUser
--
-- SELECT * FROM dwh.dimension_users WHERE user_id >= 200000000;
-- SELECT * FROM dwh.facts WHERE id_note >= 7000000;
-- SELECT * FROM note_comments WHERE note_id >= 7000000;
-- SELECT * FROM wms.notes_wms WHERE note_id >= 7000000;
-- SELECT * FROM notes WHERE note_id >= 7000000;
--
-- DELETE FROM dwh.dimension_users WHERE user_id >= 200000000;
-- DELETE FROM dwh.facts WHERE id_note >= 7000000;
-- DELETE FROM note_comments WHERE note_id >= 7000000;
-- DELETE FROM wms.notes_wms WHERE note_id >= 7000000;
-- DELETE FROM notes WHERE note_id >= 7000000;
--
-- Author: Andres Gomez
-- Version: 2023-11-19

CALL insert_note (7000000, 4.000000, -72.0000000,
  '2000-12-14 19:53:24 UTC');

CALL insert_note_comment(7000000, 'opened',
  '2000-12-14 19:53:24 UTC', 200000000, 'testUser');

CALL insert_note_comment(7000000, 'commented',
  '2000-12-14 19:53:25 UTC', 200000000, 'testUser');

CALL insert_note_comment(7000000, 'closed',
  '2000-12-14 19:53:26 UTC', 200000000, 'testUser');

CALL insert_note_comment(7000000, 'reopened',
  '2000-12-14 19:53:27 UTC', 200000000, 'testUser');

SELECT n.note_id, n.created_at, n.status, n.closed_at, nc."event"
FROM notes n JOIN note_comments nc ON n.note_id = nc.note_id
WHERE n.note_id > 6000000;

SELECT *
FROM logs l
WHERE l.message LIKE '%700000%';

DELETE FROM note_comments
WHERE note_id > 6000000;
DELETE FROM notes
WHERE note_id > 6000000;
