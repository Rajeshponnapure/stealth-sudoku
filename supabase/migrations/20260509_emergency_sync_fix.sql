-- EMERGENCY DISCOVERY & DEVICE SYNC FIX
-- This simplifies the devices table to use device_id as the primary key.

-- 1. DROP and RECREATE DEVICES (Clean Slate)
DROP TABLE IF EXISTS public.devices CASCADE;
CREATE TABLE public.devices (
    device_id text PRIMARY KEY,
    user_id uuid, -- Optional, to avoid foreign key failures
    fcm_token text,
    nickname text,
    room_id text,
    pin text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. ENSURE PROFILES EXISTS
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username text UNIQUE,
    display_name text,
    email text,
    room_id text,
    secure_pin text,
    is_online boolean DEFAULT false,
    last_seen timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 3. ENSURE ROOMS EXISTS
CREATE TABLE IF NOT EXISTS public.rooms (
    id text PRIMARY KEY,
    room_name text,
    created_at timestamptz DEFAULT now()
);

-- 4. DISABLE RLS EVERYWHERE (STRICTLY UNRESTRICTED)
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages DISABLE ROW LEVEL SECURITY;

-- 5. GRANT PERMISSIONS
GRANT ALL ON TABLE public.profiles TO anon, authenticated;
GRANT ALL ON TABLE public.devices TO anon, authenticated;
GRANT ALL ON TABLE public.rooms TO anon, authenticated;
GRANT ALL ON TABLE public.chat_sessions TO anon, authenticated;
GRANT ALL ON TABLE public.messages TO anon, authenticated;
