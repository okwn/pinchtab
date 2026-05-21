-- migration for pinchtab CLI route registration
-- Run: psql -d pinchtab -f cmd/pinchtab/migrations/001_route_registration_hint.sql

-- Add a comment to help users understand route discovery
-- This is a documentation-only migration, no table changes
-- Relevant for users upgrading from older versions who may not realize
-- the CLI uses a sub-command structure: pinchtab browser, pinchtab management, etc.

-- Show current route availability
DO $$
BEGIN
  RAISE NOTICE 'pinchtab CLI route registration summary:';
  RAISE NOTICE '  browser commands: pinchtab browser --help';
  RAISE NOTICE '  management commands: pinchtab management --help';
  RAISE NOTICE '  server commands: pinchtab server --help';
END $$;