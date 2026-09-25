-- part requests: teams ask for parts, organizers mark them fulfilled/declined.
-- reads are public; inserts go through submit_request(); status changes need the organizer pin.

create table public.part_requests (
  id         bigint generated always as identity primary key,
  team       text        not null check (char_length(team) between 1 and 40),
  part       text        not null check (char_length(part) between 1 and 120),
  qty        text        not null default '' check (char_length(qty) <= 10),
  notes      text        not null default '' check (char_length(notes) <= 240),
  status     text        not null default 'open' check (status in ('open','fulfilled','declined')),
  created_at timestamptz not null default now()
);

alter table public.part_requests enable row level security;
create policy "anyone can read part requests" on public.part_requests for select using (true);
grant select on public.part_requests to anon, authenticated;

-- private: never exposed to anon
create table public.organizer_secrets (name text primary key, value text not null);
alter table public.organizer_secrets enable row level security;
revoke all on public.organizer_secrets from anon, authenticated;
-- the pin row is inserted out-of-band (not committed): insert into organizer_secrets values ('pin', '<pin>');

create function public.submit_request(p_team text, p_part text, p_qty text, p_notes text)
returns public.part_requests
language plpgsql security definer set search_path = public
as $$
declare v_row public.part_requests;
begin
  if btrim(coalesce(p_team,'')) = '' or btrim(coalesce(p_part,'')) = '' then
    raise exception 'team and part are required';
  end if;
  insert into public.part_requests (team, part, qty, notes)
  values (left(btrim(p_team),40), left(btrim(p_part),120), left(btrim(coalesce(p_qty,'')),10), left(btrim(coalesce(p_notes,'')),240))
  returning * into v_row;
  return v_row;
end;
$$;

create function public.set_request_status(p_id bigint, p_status text, p_pin text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_pin is distinct from (select value from organizer_secrets where name = 'pin') then
    raise exception 'organizer pin required';
  end if;
  if p_status not in ('open','fulfilled','declined') then
    raise exception 'bad status';
  end if;
  update part_requests set status = p_status where id = p_id;
end;
$$;

revoke execute on function public.submit_request(text, text, text, text) from public;
revoke execute on function public.set_request_status(bigint, text, text) from public;
grant execute on function public.submit_request(text, text, text, text) to anon, authenticated;
grant execute on function public.set_request_status(bigint, text, text) to anon, authenticated;

alter publication supabase_realtime add table public.part_requests;
