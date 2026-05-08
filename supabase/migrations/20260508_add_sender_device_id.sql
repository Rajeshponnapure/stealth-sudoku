alter table public.messages
add column if not exists sender_device_id text;

create index if not exists messages_sender_device_id_idx
on public.messages(sender_device_id);
