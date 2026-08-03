-- ============================================
-- Sound Effects / Soundboard (Shared) - v3
-- Idempotent: safe to run multiple times.
-- Run ALL of this in Supabase SQL Editor.
-- ============================================

-- 1. Table
CREATE TABLE IF NOT EXISTS sound_effects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  duration INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Index
CREATE INDEX IF NOT EXISTS idx_sound_effects_created_at ON sound_effects(created_at DESC);

-- 3. RLS
ALTER TABLE sound_effects ENABLE ROW LEVEL SECURITY;

-- Drop old versions of policies first (so re-running never errors)
DROP POLICY IF EXISTS "sound_effects_select" ON sound_effects;
DROP POLICY IF EXISTS "sound_effects_insert" ON sound_effects;
DROP POLICY IF EXISTS "sound_effects_delete" ON sound_effects;
DROP POLICY IF EXISTS "sound_effects_update" ON sound_effects;

-- Everyone (authenticated) can see all sounds -> shared soundboard
CREATE POLICY "sound_effects_select" ON sound_effects FOR SELECT USING (auth.uid() IS NOT NULL);
-- Owner can insert their own sounds
CREATE POLICY "sound_effects_insert" ON sound_effects FOR INSERT WITH CHECK (auth.uid() = user_id);
-- Owner can delete their own sounds; owner/admin roles can delete any
CREATE POLICY "sound_effects_delete" ON sound_effects FOR DELETE USING (
  auth.uid() = user_id
  OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('owner', 'admin'))
);
-- Rename: owner can rename own sounds; owner/admin can rename any
CREATE POLICY "sound_effects_update" ON sound_effects FOR UPDATE USING (
  auth.uid() = user_id
  OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('owner', 'admin'))
);

-- 4. Realtime: live refresh when someone adds/edits/deletes a sound
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'sound_effects'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sound_effects;
  END IF;
END $$;
