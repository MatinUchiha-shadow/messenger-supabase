-- ============================================
-- FIX: Add avatars storage bucket and update RLS
-- ============================================

-- Create avatars bucket (run in Supabase Dashboard > Storage)
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT DO NOTHING;

-- Allow authenticated users to upload avatars
CREATE POLICY "avatars_upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.uid() IS NOT NULL);

-- Allow anyone to view avatars
CREATE POLICY "avatars_select" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');

-- Allow users to update their own avatars
CREATE POLICY "avatars_update" ON storage.objects FOR UPDATE USING (bucket_id = 'avatars' AND auth.uid() IS NOT NULL);

-- Allow users to delete their own avatars
CREATE POLICY "avatars_delete" ON storage.objects FOR DELETE USING (bucket_id = 'avatars' AND auth.uid() IS NOT NULL);

-- Also ensure uploads bucket exists
INSERT INTO storage.buckets (id, name, public) VALUES ('uploads', 'uploads', true) ON CONFLICT DO NOTHING;

-- Allow authenticated users to upload to uploads bucket
CREATE POLICY "uploads_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'uploads' AND auth.uid() IS NOT NULL);
CREATE POLICY "uploads_select" ON storage.objects FOR SELECT USING (bucket_id = 'uploads');

-- Also ensure chat-images and chat-videos buckets exist
INSERT INTO storage.buckets (id, name, public) VALUES ('chat-images', 'chat-images', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('chat-videos', 'chat-videos', true) ON CONFLICT DO NOTHING;

CREATE POLICY "chat-images-insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'chat-images' AND auth.uid() IS NOT NULL);
CREATE POLICY "chat-images-select" ON storage.objects FOR SELECT USING (bucket_id = 'chat-images');
CREATE POLICY "chat-videos-insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'chat-videos' AND auth.uid() IS NOT NULL);
CREATE POLICY "chat-videos-select" ON storage.objects FOR SELECT USING (bucket_id = 'chat-videos');
