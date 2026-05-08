-- Add sender_device_id if missing
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS sender_device_id text;

-- Devices table to map device_id -> fcm_token + user
CREATE TABLE IF NOT EXISTS public.devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  device_id text NOT NULL,
  fcm_token text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS devices_device_id_idx ON public.devices(device_id);
CREATE INDEX IF NOT EXISTS devices_user_id_idx ON public.devices(user_id);

-- Push requests queue (Edge Function or worker will read and clear these)
CREATE TABLE IF NOT EXISTS public.push_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid REFERENCES public.messages(id) ON DELETE CASCADE,
  payload jsonb NOT NULL,
  created_at timestamptz DEFAULT now(),
  processed boolean DEFAULT false,
  processed_at timestamptz
);
CREATE INDEX IF NOT EXISTS push_requests_processed_idx ON public.push_requests(processed);

-- Trigger function to enqueue push_requests on new messages
CREATE OR REPLACE FUNCTION public.enqueue_push_request() RETURNS trigger AS $$
DECLARE
  p jsonb;
BEGIN
  p := jsonb_build_object(
    'message_id', NEW.id,
    'room_id', NEW.room_id,
    'sender_id', NEW.sender_id,
    'sender_device_id', NEW.sender_device_id,
    'content', COALESCE(NEW.content, ''),
    'created_at', NEW.created_at
  );
  INSERT INTO public.push_requests (message_id, payload) VALUES (NEW.id, p);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS messages_enqueue_push_request ON public.messages;
CREATE TRIGGER messages_enqueue_push_request
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.enqueue_push_request();
