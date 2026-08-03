-- ============================================
-- SFX Events Table - DB-based sfx playback
-- Uses postgres_changes instead of broadcast
-- ============================================
CREATE TABLE IF NOT EXISTS sfx_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sound_url TEXT NOT NULL,
  sound_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sfx_events_room_id ON sfx_events(room_id);
CREATE INDEX IF NOT EXISTS idx_sfx_events_created_at ON sfx_events(created_at DESC);

ALTER TABLE sfx_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sfx_events_select" ON sfx_events;
DROP POLICY IF EXISTS "sfx_events_insert" ON sfx_events;

CREATE POLICY "sfx_events_select" ON sfx_events FOR SELECT USING (true);
CREATE POLICY "sfx_events_insert" ON sfx_events FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Add to realtime
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'sfx_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sfx_events;
  END IF;
END $$;

-- Auto-cleanup: delete events older than 1 hour
CREATE OR REPLACE FUNCTION cleanup_sfx_events() RETURNS trigger AS $$
BEGIN
  DELETE FROM sfx_events WHERE created_at < NOW() - INTERVAL '1 hour';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_cleanup_sfx_events ON sfx_events;
CREATE TRIGGER trigger_cleanup_sfx_events AFTER INSERT ON sfx_events
  FOR EACH STATEMENT EXECUTE FUNCTION cleanup_sfx_events();
