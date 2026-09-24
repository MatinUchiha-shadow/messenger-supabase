-- GapChat schema for nnxmxpcbuqgyytufjeez
-- Run this in Supabase Dashboard > SQL Editor > New Query > Run
-- This will fix the missing tables after migrating from dvhjswspljxbjxngetdc

-- 1. Extend existing profiles table (already has id, display_name, email, created_at)
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists role text default 'user';
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists banner_url text;
alter table public.profiles add column if not exists voice_seconds integer default 0;

-- 2. rooms
create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text default 'text',
  created_by uuid references public.profiles(id) on delete set null,
  is_dm boolean default false,
  created_at timestamptz default now()
);
create index if not exists rooms_name_idx on public.rooms(name);
create index if not exists rooms_is_dm_idx on public.rooms(is_dm);

-- 3. messages
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references public.rooms(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  type text default 'text',
  content text,
  file_url text,
  file_name text,
  file_size bigint,
  reply_to_id uuid,
  reply_to_name text,
  reply_to_text text,
  deleted boolean default false,
  created_at timestamptz default now()
);
create index if not exists messages_room_id_idx on public.messages(room_id);
create index if not exists messages_created_at_idx on public.messages(created_at);
create index if not exists messages_user_id_idx on public.messages(user_id);

-- 4. message_reactions
create table if not exists public.message_reactions (
  msg_id uuid references public.messages(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  reaction_key text not null,
  created_at timestamptz default now(),
  primary key (msg_id, user_id, reaction_key)
);

-- 5. invite_tokens
create table if not exists public.invite_tokens (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references public.rooms(id) on delete cascade not null,
  created_by uuid references public.profiles(id) on delete set null,
  token text unique not null,
  expires_at timestamptz,
  max_uses integer default 0,
  uses integer default 0,
  created_at timestamptz default now()
);
create index if not exists invite_tokens_token_idx on public.invite_tokens(token);

-- 6. push_subscriptions
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  subscription text not null,
  created_at timestamptz default now(),
  unique(user_id)
);

-- 7. sound_effects
create table if not exists public.sound_effects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  file_url text not null,
  duration numeric,
  created_at timestamptz default now()
);

-- 8. Enable RLS and create permissive policies for authenticated users
alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.invite_tokens enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.sound_effects enable row level security;

-- Drop existing policies if any to avoid conflict
drop policy if exists "profiles_all" on public.profiles;
drop policy if exists "rooms_all" on public.rooms;
drop policy if exists "messages_all" on public.messages;
drop policy if exists "message_reactions_all" on public.message_reactions;
drop policy if exists "invite_tokens_all" on public.invite_tokens;
drop policy if exists "push_subscriptions_all" on public.push_subscriptions;
drop policy if exists "sound_effects_all" on public.sound_effects;

-- Allow anon/authenticated to read profiles (GapChat needs to list users)
create policy "profiles_all" on public.profiles for all using (true) with check (true);
create policy "rooms_all" on public.rooms for all using (true) with check (true);
create policy "messages_all" on public.messages for all using (true) with check (true);
create policy "message_reactions_all" on public.message_reactions for all using (true) with check (true);
create policy "invite_tokens_all" on public.invite_tokens for all using (true) with check (true);
create policy "push_subscriptions_all" on public.push_subscriptions for all using (true) with check (true);
create policy "sound_effects_all" on public.sound_effects for all using (true) with check (true);

-- 9. Storage buckets (public)
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('chat-images', 'chat-images', true) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('chat-videos', 'chat-videos', true) on conflict (id) do nothing;

-- Storage policies: allow all
drop policy if exists "avatars_all" on storage.objects;
drop policy if exists "chat_images_all" on storage.objects;
create policy "avatars_all" on storage.objects for all using (true) with check (true);
-- Note: if above fails due to existing policies, run separately in dashboard

-- 10. Realtime: enable replica identity for realtime
-- (Supabase realtime needs publication)
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.message_reactions;
