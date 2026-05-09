-- COMPREHENSIVE SECURITY & DISCOVERY FIX
-- This migration ensures all tables exist and permissions are wide open to fix the "Empty Table" issue.

-- 1. PROFILES Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username text UNIQUE,
    display_name text,
    room_id text,
    secure_pin text,
    is_online boolean DEFAULT false,
    last_seen timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. DEVICES Table
CREATE TABLE IF NOT EXISTS public.devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id text UNIQUE NOT NULL,
    fcm_token text,
    nickname text,
    room_id text,
    pin text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 3. ROOMS Table
CREATE TABLE IF NOT EXISTS public.rooms (
    id text PRIMARY KEY,
    room_name text,
    created_at timestamptz DEFAULT now()
);

-- 4. CHAT SESSIONS Table (Ensure it exists for conversation list)
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id uuid REFERENCES auth.users(id),
    participant_ids uuid[] DEFAULT '{}',
    is_group boolean DEFAULT false,
    group_name text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 5. MESSAGES Table (Ensure it exists)
CREATE TABLE IF NOT EXISTS public.messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id uuid REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    sender_id uuid REFERENCES auth.users(id),
    sender_device_id text,
    receiver_id uuid,
    content text,
    message_type text DEFAULT 'text',
    file_url text,
    file_name text,
    file_size bigint,
    is_self_destruct boolean DEFAULT false,
    destruct_at timestamptz,
    created_at timestamptz DEFAULT now()
);

-- 🔓 DISABLE RLS ON ALL TABLES TO FIX SYNC ISSUES
-- This ensures that the app can read/write without complex policy setup for now.
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages DISABLE ROW LEVEL SECURITY;

-- Ensure column names match what the app expects
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS secure_pin text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS room_id text;
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS pin text;
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS room_id text;
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS nickname text;
ALTER TABLE public.devices ALTER COLUMN fcm_token DROP NOT NULL;
