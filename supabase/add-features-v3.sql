-- ============================================
-- Feature Additions v3: Reactions, Delete-for-All, Invite Links
-- Idempotent: safe to run multiple times.
-- ============================================

-- 1. Add deleted column to messages (for delete-for-everyone)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='messages' AND column_name='deleted') THEN
    ALTER TABLE messages ADD COLUMN deleted BOOLEAN DEFAULT false;
  END IF;
END $$;

-- 2. Message Reactions table
CREATE TABLE IF NOT EXISTS message_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  msg_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reaction_key TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(msg_id, user_id, reaction_key)
);

CREATE INDEX IF NOT EXISTS idx_msg_reactions_msg_id ON message_reactions(msg_id);

ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "msg_reactions_select" ON message_reactions;
DROP POLICY IF EXISTS "msg_reactions_insert" ON message_reactions;
DROP POLICY IF EXISTS "msg_reactions_delete" ON message_reactions;

CREATE POLICY "msg_reactions_select" ON message_reactions FOR SELECT USING (true);
CREATE POLICY "msg_reactions_insert" ON message_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "msg_reactions_delete" ON message_reactions FOR DELETE USING (auth.uid() = user_id);

-- 3. Invite Tokens table
CREATE TABLE IF NOT EXISTS invite_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token TEXT UNIQUE NOT NULL,
  expires_at TIMESTAMPTZ,
  max_uses INTEGER DEFAULT 0,
  uses INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invite_tokens_token ON invite_tokens(token);

ALTER TABLE invite_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "invite_tokens_select" ON invite_tokens;
DROP POLICY IF EXISTS "invite_tokens_insert" ON invite_tokens;
DROP POLICY IF EXISTS "invite_tokens_update" ON invite_tokens;

CREATE POLICY "invite_tokens_select" ON invite_tokens FOR SELECT USING (true);
CREATE POLICY "invite_tokens_insert" ON invite_tokens FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "invite_tokens_update" ON invite_tokens FOR UPDATE USING (auth.uid() = created_by);

-- 4. UPDATE policy for messages (delete-for-everyone sets deleted=true)
DROP POLICY IF EXISTS "messages_update" ON messages;
CREATE POLICY "messages_update" ON messages FOR UPDATE USING (auth.uid() = user_id);

-- 5. Add message_reactions to realtime
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'message_reactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE message_reactions;
  END IF;
END $$;
