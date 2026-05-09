-- MINIMAL SCHEMA FOR 1-ON-1 CHAT APP (No Rooms, No Groups)
-- This matches your WhatsApp-like DM functionality

-- 1. PROFILES TABLE (User info)
-- Stores: id, username, display_name, email, online status
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username text UNIQUE NOT NULL,
    display_name text,
    email text,
    is_online boolean DEFAULT false,
    last_seen timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. FRIEND_REQUESTS TABLE (Friend requests + Friendships)
-- Stores: who sent request, who receives, status (pending/accepted/rejected)
-- When status='accepted' = they are friends and can chat
CREATE TABLE IF NOT EXISTS public.friend_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status text DEFAULT 'pending', -- pending, accepted, rejected
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(sender_id, receiver_id)
);

-- 3. CHAT_SESSIONS TABLE (1-on-1 conversations)
-- Stores: chat_id, creator_id, participant_ids (array of 2 users)
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id uuid REFERENCES auth.users(id),
    participant_ids uuid[] DEFAULT '{}', -- Array of 2 user IDs
    is_group boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 4. MESSAGES TABLE (Chat messages)
-- Stores: chat_id, sender_id, content, file info, self-destruct
CREATE TABLE IF NOT EXISTS public.messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id uuid REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    sender_id uuid REFERENCES auth.users(id),
    receiver_id uuid,
    content text,
    message_type text DEFAULT 'text', -- text, image, audio, video, file
    file_url text,
    file_name text,
    file_size bigint,
    is_self_destruct boolean DEFAULT false,
    destruct_at timestamptz,
    created_at timestamptz DEFAULT now()
);

-- 5. DISABLE RLS (Open access for development)
-- Later you can enable RLS with proper policies
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages DISABLE ROW LEVEL SECURITY;

-- 6. GRANT PERMISSIONS
GRANT ALL ON TABLE public.profiles TO anon, authenticated;
GRANT ALL ON TABLE public.friend_requests TO anon, authenticated;
GRANT ALL ON TABLE public.chat_sessions TO anon, authenticated;
GRANT ALL ON TABLE public.messages TO anon, authenticated;

-- 7. INDEXES FOR SPEED
CREATE INDEX IF NOT EXISTS idx_friend_requests_sender ON public.friend_requests(sender_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver ON public.friend_requests(receiver_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_status ON public.friend_requests(status);
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON public.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at);
