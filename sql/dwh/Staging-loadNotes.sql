-- Loads data warehouse data.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-31

SELECT /* Notes-staging */ COUNT(1) AS facts, 0 AS comments
FROM dwh.facts
UNION
SELECT /* Notes-staging */ 0 AS facts, count(1) AS comments
FROM note_comments;

SELECT /* Notes-staging */ CURRENT_TIMESTAMP AS Processing,
 'Inserting facts' AS Task;

CALL staging.process_notes_actions_into_dwh();

SELECT /* Notes-staging */ CURRENT_TIMESTAMP AS Processing,
 'Facts inserted' AS Task;

SELECT /* Notes-staging */ COUNT(1) AS facts, 0 AS comments
FROM dwh.facts
UNION
SELECT /* Notes-staging */ 0 AS facts, count(1) AS comments
FROM note_comments;
