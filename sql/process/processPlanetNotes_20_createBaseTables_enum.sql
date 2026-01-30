-- Create base enumerators.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-19

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
    CREATE TYPE note_status_enum AS ENUM (
      'open',
      'close',
      'hidden'
    );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_event_enum') THEN
    CREATE TYPE note_event_enum AS ENUM (
      'opened',
      'closed',
      'reopened',
      'commented',
      'hidden'
    );
  END IF;
END $$;
