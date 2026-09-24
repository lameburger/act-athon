-- hardware queue: one row per booking of one tool unit.
-- reads are public; writes only go through book() / return_booking(), which enforce the rules.

create extension if not exists btree_gist;

create table public.bookings (
  id         bigint generated always as identity primary key,
  unit       text        not null,
  team       text        not null check (char_length(team) between 1 and 40),
  start_at   timestamptz not null,
  end_at     timestamptz not null,
  created_at timestamptz not null default now(),
  check (end_at > start_at),
  -- no two bookings of the same unit may overlap, even under concurrent requests
  exclude using gist (unit with =, tstzrange(start_at, end_at) with &&)
);

alter table public.bookings enable row level security;
create policy "anyone can read bookings" on public.bookings for select using (true);
grant select on public.bookings to anon, authenticated;

create function public.book(p_unit text, p_team text, p_start timestamptz, p_minutes int)
returns public.bookings
language plpgsql security definer set search_path = public
as $$
declare
  v_start timestamptz := greatest(p_start, now());
  v_team  text := btrim(p_team);
  v_row   public.bookings;
begin
  if p_unit !~ '^q_(solder_[1-4]|hotglue_[1-3]|welder_1|psu_[1-3]|jackery_[1-3])$' then
    raise exception 'unknown unit';
  end if;
  if v_team = '' or char_length(v_team) > 40 then
    raise exception 'team name must be 1-40 characters';
  end if;
  if p_minutes is null or p_minutes < 1 or p_minutes > 60 then
    raise exception 'max lease is 60 minutes';
  end if;
  if v_start > now() + interval '61 minutes' then
    raise exception 'you can only book a slot starting within the next hour';
  end if;

  insert into public.bookings (unit, team, start_at, end_at)
  values (p_unit, v_team, v_start, v_start + make_interval(mins => p_minutes))
  returning * into v_row;
  return v_row;
exception when exclusion_violation then
  raise exception 'already booked for that window - pick another time or unit';
end;
$$;

-- end an active lease early so the next team can grab it
create function public.return_booking(p_id bigint)
returns void
language sql security definer set search_path = public
as $$
  update public.bookings set end_at = now()
  where id = p_id and start_at <= now() and end_at > now();
$$;

revoke execute on function public.book(text, text, timestamptz, int) from public;
revoke execute on function public.return_booking(bigint) from public;
grant execute on function public.book(text, text, timestamptz, int) to anon, authenticated;
grant execute on function public.return_booking(bigint) to anon, authenticated;

-- push changes to open pages
alter publication supabase_realtime add table public.bookings;
