-- Migrates missing columns to existing tables.
-- This script ensures that tables have all required columns even if they
-- were created with an older version of the schema.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-12

-- Create ENUM types if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
    CREATE TYPE note_status_enum AS ENUM (
      'open',
      'close',
      'hidden'
    );
    RAISE NOTICE 'Created note_status_enum type';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_event_enum') THEN
    CREATE TYPE note_event_enum AS ENUM (
      'opened',
      'closed',
      'reopened',
      'commented',
      'hidden'
    );
    RAISE NOTICE 'Created note_event_enum type';
  END IF;
END $$;

-- Add status column to notes table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'notes'
    AND column_name = 'status'
  ) THEN
    ALTER TABLE notes ADD COLUMN status note_status_enum;
    RAISE NOTICE 'Added status column to notes table';
  END IF;
END $$;

-- Add status column to notes_check table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'notes_check'
    AND column_name = 'status'
  ) THEN
    -- Only add column if table exists
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = 'notes_check'
    ) THEN
      ALTER TABLE notes_check ADD COLUMN status note_status_enum;
      RAISE NOTICE 'Added status column to notes_check table';
    END IF;
  END IF;
END $$;

-- Add part_id column to notes_api table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'notes_api'
    AND column_name = 'part_id'
  ) THEN
    -- Only add column if table exists
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = 'notes_api'
    ) THEN
      ALTER TABLE notes_api ADD COLUMN part_id INTEGER;
      RAISE NOTICE 'Added part_id column to notes_api table';
    END IF;
  END IF;
END $$;

-- Add part_id column to note_comments_api table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'note_comments_api'
    AND column_name = 'part_id'
  ) THEN
    -- Only add column if table exists
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = 'note_comments_api'
    ) THEN
      ALTER TABLE note_comments_api ADD COLUMN part_id INTEGER;
      RAISE NOTICE 'Added part_id column to note_comments_api table';
    END IF;
  END IF;
END $$;

-- Add part_id column to note_comments_text_api table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'note_comments_text_api'
    AND column_name = 'part_id'
  ) THEN
    -- Only add column if table exists
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = 'note_comments_text_api'
    ) THEN
      ALTER TABLE note_comments_text_api ADD COLUMN part_id INTEGER;
      RAISE NOTICE 'Added part_id column to note_comments_text_api table';
    END IF;
  END IF;
END $$;

