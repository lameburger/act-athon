-- mirror open part requests into the pinned #part-requests discord message.
-- the hook secret lives in organizer_secrets (name = 'hook'), inserted out-of-band.
create extension if not exists pg_net;

create function public.notify_discord_requests()
returns trigger
language plpgsql security definer set search_path = public, extensions
as $$
begin
  perform net.http_post(
    url := 'https://opaxaoyqjnutfdzxrefz.supabase.co/functions/v1/discord-requests',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-hook-secret', (select value from organizer_secrets where name = 'hook')
    ),
    body := '{}'::jsonb
  );
  return null;
end;
$$;

create trigger part_requests_to_discord
after insert or update or delete on public.part_requests
for each statement execute function public.notify_discord_requests();
