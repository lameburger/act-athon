-- judge rankings: each judge orders all teams 1..N via a private per-judge key.
-- nothing here is readable by anon; access only through key/pin-checked functions.
create table public.judge_keys (
  key   text primary key,
  judge text not null unique
);
alter table public.judge_keys enable row level security;
revoke all on public.judge_keys from anon, authenticated;

create table public.judge_rankings (
  judge      text primary key,
  ranking    jsonb not null,           -- ordered array of team names, best first
  updated_at timestamptz not null default now()
);
alter table public.judge_rankings enable row level security;
revoke all on public.judge_rankings from anon, authenticated;

create function public.judge_whoami(p_key text)
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'judge', k.judge,
    'ranking', (select ranking from judge_rankings r where r.judge = k.judge))
  from judge_keys k where k.key = p_key;
$$;

create function public.submit_ranking(p_key text, p_ranking jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_judge text;
begin
  select judge into v_judge from judge_keys where key = p_key;
  if v_judge is null then raise exception 'invalid judge link'; end if;
  if jsonb_typeof(p_ranking) <> 'array' or jsonb_array_length(p_ranking) > 40 then
    raise exception 'bad ranking';
  end if;
  insert into judge_rankings (judge, ranking, updated_at) values (v_judge, p_ranking, now())
  on conflict (judge) do update set ranking = excluded.ranking, updated_at = now();
end; $$;

-- results for organizers only (same pin as part requests)
create function public.judge_results(p_pin text)
returns table (judge text, ranking jsonb, updated_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if p_pin is distinct from (select value from organizer_secrets where name = 'pin') then
    raise exception 'organizer pin required';
  end if;
  return query select r.judge, r.ranking, r.updated_at from judge_rankings r order by r.judge;
end; $$;

revoke execute on function public.judge_whoami(text) from public;
revoke execute on function public.submit_ranking(text, jsonb) from public;
revoke execute on function public.judge_results(text) from public;
grant execute on function public.judge_whoami(text) to anon, authenticated;
grant execute on function public.submit_ranking(text, jsonb) to anon, authenticated;
grant execute on function public.judge_results(text) to anon, authenticated;
