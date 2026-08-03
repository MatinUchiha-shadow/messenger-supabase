-- ============================================
-- fix-all.sql — همه مهاجرت‌های ضروری در یک فایل
-- کافیست این فایل رو توی SQL Editor اجرا کنی
-- ============================================

-- 1. ستون banner_url برای بنر پروفایل
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS banner_url TEXT;

-- 2. ستون video_type برای پیام‌های صوتی/ویدیویی
ALTER TABLE messages ADD COLUMN IF NOT EXISTS video_type TEXT;

-- 3. گسترش رنک‌ها به ۶ تا
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check 
  CHECK (role IN ('owner', 'admin', 'mod', 'vip', 'active', 'user'));

-- 4. پالیسی آپدیت پروفایل (برای بنر و رنک)
DROP POLICY IF EXISTS "profiles_update_banner" ON profiles;
CREATE POLICY "profiles_update_banner" ON profiles FOR UPDATE 
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_role" ON profiles;
CREATE POLICY "profiles_update_role" ON profiles FOR UPDATE 
  USING (auth.uid() = id OR auth.uid() IN (SELECT id FROM profiles WHERE role = 'owner'));

-- 5. پالیسی حذف اتاق (owner + admin + mod)
DROP POLICY IF EXISTS "rooms_delete" ON rooms;
CREATE POLICY "rooms_delete" ON rooms FOR DELETE 
  USING (auth.uid() = created_by OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('owner', 'admin', 'mod')));
