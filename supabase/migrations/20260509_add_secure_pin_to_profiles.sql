-- Add secure_pin to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS secure_pin text,
ADD COLUMN IF NOT EXISTS room_id text;

-- Ensure username is unique for login
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_username_key') THEN
        ALTER TABLE public.profiles ADD CONSTRAINT profiles_username_key UNIQUE (username);
    END IF;
END $$;

-- Ensure rooms table exists
CREATE TABLE IF NOT EXISTS public.rooms (
  id text PRIMARY KEY,
  room_name text,
  created_at timestamptz DEFAULT now()
);

-- Also ensure devices table has the pin column (used in current AuthService)
ALTER TABLE public.devices
ADD COLUMN IF NOT EXISTS pin text,
ADD COLUMN IF NOT EXISTS nickname text,
ADD COLUMN IF NOT EXISTS room_id text,
ALTER COLUMN fcm_token DROP NOT NULL; -- ✅ Allow NULL if token isn't ready yet
