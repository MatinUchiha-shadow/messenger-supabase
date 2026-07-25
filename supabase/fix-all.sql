-- ============================================
-- COMPLETE FIX: Run this in Supabase SQL Editor
-- ============================================

-- 1. Add bio column to profiles (if not exists)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';

-- 2. Create storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('uploads', 'uploads', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('chat-images', 'chat-images', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('chat-videos', 'chat-videos', true) ON CONFLICT DO NOTHING;

-- 3. Drop old policies if they exist
DROP POLICY IF EXISTS "avatars_upload" ON storage.objects;
DROP POLICY IF EXISTS "avatars_select" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete" ON storage.objects;
DROP POLICY IF EXISTS "uploads_insert" ON storage.objects;
DROP POLICY IF EXISTS "uploads_select" ON storage.objects;
DROP POLICY IF EXISTS "chat-images-insert" ON storage.objects;
DROP POLICY IF EXISTS "chat-images-select" ON storage.objects;
DROP POLICY IF EXISTS "chat-videos-insert" ON storage.objects;
DROP POLICY IF EXISTS "chat-videos-select" ON storage.objects;

-- 4. Create storage policies (allow all for authenticated)
CREATE POLICY "avatars_all" ON storage.objects FOR ALL USING (bucket_id = 'avatars') WITH CHECK (bucket_id = 'avatars');
CREATE POLICY "uploads_all" ON storage.objects FOR ALL USING (bucket_id = 'uploads') WITH CHECK (bucket_id = 'uploads');
CREATE POLICY "chat-images_all" ON storage.objects FOR ALL USING (bucket_id = 'chat-images') WITH CHECK (bucket_id = 'chat-images');
CREATE POLICY "chat-videos_all" ON storage.objects FOR ALL USING (bucket_id = 'chat-videos') WITH CHECK (bucket_id = 'chat-videos');
