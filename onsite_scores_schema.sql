-- Create table for onsite scores
create table if not exists public.onsite_scores (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references public.teams(id) on delete cascade,
  judge_id uuid references public.judges(id) on delete cascade,
  suitable text,
  appearance integer,
  color integer,
  skin integer,
  moisture integer,
  meat_sauce integer,
  completeness jsonb,
  created_at timestamptz not null default now()
);

-- Enable RLS
alter table public.onsite_scores enable row level security;

-- Read for everyone
create policy if not exists onsite_scores_select_all 
  on public.onsite_scores for select using (true);

-- Allow inserts
create policy if not exists onsite_scores_insert_all 
  on public.onsite_scores for insert with check (true);

-- Index for performance
create index if not exists idx_onsite_scores_team 
  on public.onsite_scores (team_id);
create index if not exists idx_onsite_scores_judge 
  on public.onsite_scores (judge_id);
