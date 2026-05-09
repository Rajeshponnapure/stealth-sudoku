-- Fix missing email column in profiles table
-- This is causing account creation to fail

-- Add email column if it doesn't exist
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;

-- Grant permissions
GRANT ALL ON TABLE public.profiles TO anon, authenticated;

-- Ensure RLS is disabled (or add proper policies if enabled)
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
