-- Verifies if the base tables contain historical data.
-- This validation ensures that processAPI doesn't run without historical notes.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-08-07

DO /* Notes-historical-checkData */
$$
DECLARE
 qty INT;
 oldest_note_date DATE;
 oldest_comment_date DATE;
 current_date_check DATE := CURRENT_DATE;
 min_historical_days INT := 30; -- Minimum days of historical data required
BEGIN
 -- Check if notes table has data
 SELECT /* Notes-historical-notes-count */ COUNT(*)
  INTO qty
 FROM notes;
 
 IF (qty = 0) THEN
  RAISE EXCEPTION 'Historical data validation failed: notes table is empty. Please run processPlanetNotes.sh first to load historical data.';
 END IF;

 -- Check if note_comments table has data
 SELECT /* Notes-historical-comments-count */ COUNT(*)
  INTO qty
 FROM note_comments;
 
 IF (qty = 0) THEN
  RAISE EXCEPTION 'Historical data validation failed: note_comments table is empty. Please run processPlanetNotes.sh first to load historical data.';
 END IF;

 -- Check if we have historical data (not just recent data)
 SELECT /* Notes-historical-oldest-note */ MIN(date_created::DATE)
  INTO oldest_note_date
 FROM notes
 WHERE date_created IS NOT NULL;

 IF (oldest_note_date IS NULL) THEN
  RAISE EXCEPTION 'Historical data validation failed: no valid creation dates found in notes table.';
 END IF;

 -- Check if we have at least minimum historical data
 IF (current_date_check - oldest_note_date < min_historical_days) THEN
  RAISE EXCEPTION 'Historical data validation failed: insufficient historical data. Found data from %, but need at least % days of history. Please run processPlanetNotes.sh first.', 
   oldest_note_date, min_historical_days;
 END IF;

 -- Check if we have historical comments data
 SELECT /* Notes-historical-oldest-comment */ MIN(date::DATE)
  INTO oldest_comment_date
 FROM note_comments
 WHERE date IS NOT NULL;

 IF (oldest_comment_date IS NULL) THEN
  RAISE EXCEPTION 'Historical data validation failed: no valid dates found in note_comments table.';
 END IF;

 -- Check if comments historical data aligns with notes
 IF (current_date_check - oldest_comment_date < min_historical_days) THEN
  RAISE EXCEPTION 'Historical data validation failed: insufficient historical comment data. Found data from %, but need at least % days of history.', 
   oldest_comment_date, min_historical_days;
 END IF;

 -- Log successful validation
 RAISE NOTICE 'Historical data validation passed: Found notes from % and comments from % (% and % days of history respectively)', 
  oldest_note_date, oldest_comment_date, 
  (current_date_check - oldest_note_date), 
  (current_date_check - oldest_comment_date);

END;
$$;
