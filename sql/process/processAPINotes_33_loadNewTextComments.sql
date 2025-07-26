-- Insert new text comments.
-- Sequence numbers are already generated in XSLT transformation
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-26

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Inserting text comments with sequence numbers from XSLT' AS Text;

-- Insert text comments directly from API tables
-- Sequence numbers are already provided by XSLT transformation
INSERT INTO note_comments_text (note_id, sequence_action, body)
 SELECT /* Notes-processAPI */ note_id, sequence_action, body FROM note_comments_text_api
 ON CONFLICT DO NOTHING;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Text comments inserted successfully' AS Text;