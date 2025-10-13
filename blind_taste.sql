-- Create table for blind taste records
create table if not exists public.blind_taste (
  id uuid primary key default gen_random_uuid(),
  judge_id text not null,
  chip_number integer not null,
  score_appearance numeric,
  score_tenderness numeric,
  score_flavor numeric,
  score1 numeric,
  score2 numeric,
  score3 numeric,
  score_total numeric not null,
  created_at timestamptz not null default now()
);

-- Uniqueness: a judge may score a chip only once
create unique index if not exists blind_taste_judge_chip_uniq
  on public.blind_taste (judge_id, chip_number);

-- Enable RLS
alter table public.blind_taste enable row level security;

-- Read for everyone (adjust to your needs)
do blind-taste.html
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='blind_taste' and policyname='blind_taste_select_all'
  ) then
    create policy blind_taste_select_all on public.blind_taste
      for select using (true);
  end if;
end blind-taste.html;

-- Allow inserts from anon (no-login) — change "to anon" to "to authenticated" if you require login
do blind-taste.html
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='blind_taste' and policyname='blind_taste_insert_anon'
  ) then
    create policy blind_taste_insert_anon on public.blind_taste
      for insert to anon with check (true);
  end if;
end blind-taste.html;
