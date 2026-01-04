-- Safely swap countries_new to countries table.
--
-- This script performs a safe swap of countries_new to countries:
--   1. Renames countries to countries_old (backup)
--   2. Renames countries_new to countries
--   3. Recreates indexes and constraints
--   4. Optionally drops countries_old after verification
--
-- WARNING: This operation is irreversible if countries_old is dropped.
-- Always verify the swap before dropping the backup.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2026-01-03

-- ============================================================================
-- STEP 1: Verify countries_new exists and has data
-- ============================================================================
DO $$
DECLARE
  v_count INTEGER;
  v_table_exists BOOLEAN;
BEGIN
  -- Check if countries_new exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_name = 'countries_new'
  ) INTO v_table_exists;
  
  IF NOT v_table_exists THEN
    RAISE EXCEPTION 'countries_new table does not exist. Cannot perform swap.';
  END IF;
  
  -- Check if countries_new has data
  SELECT COUNT(*) INTO v_count FROM countries_new;
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'countries_new table is empty. Cannot perform swap.';
  END IF;
  
  RAISE NOTICE 'countries_new table exists with % countries', v_count;
END $$;

-- ============================================================================
-- STEP 2: Create backup of current countries table
-- ============================================================================
-- Drop old backup if it exists (from previous swap)
DROP TABLE IF EXISTS countries_old CASCADE;

-- Rename current countries to countries_old (creates backup)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_name = 'countries'
  ) THEN
    ALTER TABLE countries RENAME TO countries_old;
    RAISE NOTICE 'Renamed countries to countries_old (backup created)';
  ELSE
    RAISE NOTICE 'countries table does not exist, skipping backup creation';
  END IF;
END $$;

-- ============================================================================
-- STEP 3: Swap countries_new to countries
-- ============================================================================
DO $$
BEGIN
  ALTER TABLE countries_new RENAME TO countries;
  RAISE NOTICE 'Renamed countries_new to countries';
END $$;

-- ============================================================================
-- STEP 4: Verify indexes and constraints
-- ============================================================================
-- Recreate spatial index (should already exist from INCLUDING ALL, but verify)
CREATE INDEX IF NOT EXISTS countries_spatial ON countries
  USING GIST (geom);
COMMENT ON INDEX countries_spatial IS 'Spatial index for countries';

-- Recreate other indexes
CREATE INDEX IF NOT EXISTS idx_countries_update_failed ON countries (update_failed)
  WHERE update_failed = TRUE;

CREATE INDEX IF NOT EXISTS idx_countries_is_maritime ON countries (is_maritime)
  WHERE is_maritime = TRUE;

-- Verify primary key constraint
DO $$
DECLARE
  v_has_pk BOOLEAN;
BEGIN
  -- Check if table already has a primary key (any primary key, not just pk_countries)
  SELECT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conrelid = 'countries'::regclass
      AND contype = 'p'
  ) INTO v_has_pk;
  
  IF NOT v_has_pk THEN
    -- No primary key exists, create it
    ALTER TABLE countries
      ADD CONSTRAINT pk_countries
      PRIMARY KEY (country_id);
    RAISE NOTICE 'Primary key constraint created';
  ELSE
    -- Primary key already exists, check if it's named pk_countries
    IF EXISTS (
      SELECT 1 FROM pg_constraint 
      WHERE conname = 'pk_countries' 
        AND conrelid = 'countries'::regclass
    ) THEN
      RAISE NOTICE 'Primary key constraint pk_countries already exists';
    ELSE
      RAISE NOTICE 'Primary key constraint already exists with different name';
    END IF;
  END IF;
END $$;

-- ============================================================================
-- STEP 5: Update statistics
-- ============================================================================
ANALYZE countries;

-- ============================================================================
-- STEP 6: Verification
-- ============================================================================
DO $$
DECLARE
  v_count INTEGER;
  v_index_count INTEGER;
BEGIN
  -- Verify data count
  SELECT COUNT(*) INTO v_count FROM countries;
  RAISE NOTICE 'countries table now has % rows', v_count;
  
  -- Verify indexes
  SELECT COUNT(*) INTO v_index_count
  FROM pg_indexes
  WHERE tablename = 'countries';
  RAISE NOTICE 'countries table has % indexes', v_index_count;
  
  -- Verify spatial index exists
  IF EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = 'countries'
      AND indexname = 'countries_spatial'
  ) THEN
    RAISE NOTICE 'Spatial index verified';
  ELSE
    RAISE WARNING 'Spatial index not found - this may cause performance issues';
  END IF;
END $$;

-- ============================================================================
-- STEP 7: Summary
-- ============================================================================
DO $$
DECLARE
  backup_count_val INTEGER := 0;
  note_text TEXT;
BEGIN
  -- Check if countries_old exists and get count
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'countries_old') THEN
    SELECT COUNT(*) INTO backup_count_val FROM countries_old;
    note_text := 'countries_old table kept as backup. Drop manually after verification.';
  ELSE
    note_text := 'No backup table (first execution in --base mode)';
  END IF;

  -- Display summary
  RAISE NOTICE 'Swap completed successfully';
  RAISE NOTICE 'Countries count: %', (SELECT COUNT(*) FROM countries);
  RAISE NOTICE 'Backup count: %', backup_count_val;
  RAISE NOTICE 'Note: %', note_text;
END $$;

-- ============================================================================
-- OPTIONAL: Drop backup after verification
-- ============================================================================
-- Uncomment the following lines ONLY after verifying that the swap was successful
-- and that countries table is working correctly:
--
-- DROP TABLE IF EXISTS countries_old CASCADE;
-- RAISE NOTICE 'Backup table countries_old dropped';

