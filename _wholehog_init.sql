create extension if not exists pgcrypto;

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  site_number int not null,
  team_name text not null,
  chip_number text not null unique,
  created_at timestamptz default now()
);

create table if not exists public.scores (
  id uuid primary key default gen_random_uuid(),
  chip_number text not null,
  score numeric(5,2) not null check (score >= 0),
  judge_id text null,
  created_at timestamptz default now(),
  constraint fk_scores_chip foreign key (chip_number)
    references public.teams (chip_number)
    on update cascade on delete cascade
);

create index if not exists idx_scores_chip_created_at on public.scores (chip_number, created_at desc);

alter table public.teams enable row level security;
alter table public.scores enable row level security;

create policy if not exists teams_read_all   on public.teams for select using (true);
create policy if not exists scores_read_all  on public.scores for select using (true);
create policy if not exists teams_insert_all on public.teams for insert with check (true);
create policy if not exists teams_update_all on public.teams for update using (true) with check (true);
create policy if not exists scores_insert_all on public.scores for insert with check (true);

do $$
begin
  begin
    alter publication supabase_realtime add table public.teams;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.scores;
  exception when duplicate_object then null;
  end;
end $$;
