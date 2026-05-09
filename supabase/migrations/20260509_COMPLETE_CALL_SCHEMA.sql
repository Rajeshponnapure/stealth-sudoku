-- COMPLETE CALL & MEDIA SHARING SCHEMA
-- For audio/video calls and chat media

-- 1. CALLS TABLE (Track all calls)
CREATE TABLE IF NOT EXISTS public.calls (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id uuid REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    caller_id uuid REFERENCES auth.users(id),
    callee_id uuid REFERENCES auth.users(id),
    call_type text NOT NULL, -- 'audio' or 'video'
    status text DEFAULT 'ringing', -- 'ringing', 'active', 'ended', 'rejected', 'missed'
    sdp_offer text,
    sdp_answer text,
    started_at timestamptz,
    ended_at timestamptz,
    created_at timestamptz DEFAULT now()
);

-- 2. ICE_CANDIDATES TABLE (WebRTC signaling)
CREATE TABLE IF NOT EXISTS public.ice_candidates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    call_id uuid REFERENCES public.calls(id) ON DELETE CASCADE,
    sender_id text NOT NULL, -- device_id or user_id
    candidate text NOT NULL,
    sdp_mid text,
    sdp_mline_index int,
    created_at timestamptz DEFAULT now()
);

-- 3. CALL_PARTICIPANTS TABLE (Track participants in calls)
CREATE TABLE IF NOT EXISTS public.call_participants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    call_id uuid REFERENCES public.calls(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id),
    joined_at timestamptz DEFAULT now(),
    left_at timestamptz
);

-- 4. DISABLE RLS ON CALL TABLES
ALTER TABLE public.calls DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.ice_candidates DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_participants DISABLE ROW LEVEL SECURITY;

-- 5. GRANT PERMISSIONS
GRANT ALL ON TABLE public.calls TO anon, authenticated;
GRANT ALL ON TABLE public.ice_candidates TO anon, authenticated;
GRANT ALL ON TABLE public.call_participants TO anon, authenticated;

-- 6. INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_calls_chat_id ON public.calls(chat_id);
CREATE INDEX IF NOT EXISTS idx_calls_status ON public.calls(status);
CREATE INDEX IF NOT EXISTS idx_calls_caller ON public.calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_calls_callee ON public.calls(callee_id);
CREATE INDEX IF NOT EXISTS idx_ice_candidates_call_id ON public.ice_candidates(call_id);
