-- Create base enumerators.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25

CREATE TYPE note_status_enum AS ENUM (
  'open',
  'close',
  'hidden'
  );

CREATE TYPE note_event_enum AS ENUM (
 'opened',
 'closed',
 'reopened',
 'commented',
 'hidden'
 );
