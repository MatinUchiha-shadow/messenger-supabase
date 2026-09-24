-- Friend System + Voice moderation for GapChat
-- Run in Supabase Dashboard > SQL Editor

-- 1. Friend requests
create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  status text default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz default now(),
  unique(sender_id, receiver_id)
);
create index if not exists fr_sender_idx on public.friend_requests(sender_id);
create index if not exists fr_receiver_idx on public.friend_requests(receiver_id);

-- 2. Friendships (symmetric)
create table if not exists public.friendships (
  user_id uuid references public.profiles(id) on delete cascade not null,
  friend_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  primary key (user_id, friend_id)
);
create index if not exists fs_user_idx on public.friendships(user_id);

-- 3. Voice mutes/bans (optional persistent)
create table if not exists public.voice_bans (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  banned_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now(),
  unique(room_id, user_id)
);

-- RLS
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.voice_bans enable row level security;

drop policy if exists "friend_requests_all" on public.friend_requests;
drop policy if exists "friendships_all" on public.friendships;
drop policy if exists "voice_bans_all" on public.voice_bans;

create policy "friend_requests_all" on public.friend_requests for all using (true) with check (true);
create policy "friendships_all" on public.friendships for all using (true) with check (true);
create policy "voice_bans_all" on public.voice_bans for all using (true) with check (true);

-- Realtime (idempotent)
do $$ begin
  alter publication supabase_realtime add table public.friend_requests;
exception when duplicate_object then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table public.friendships;
exception when duplicate_object then null;
end $$;
