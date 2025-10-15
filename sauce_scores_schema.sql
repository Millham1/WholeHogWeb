-- Create table for sauce scores
create table if not exists public.sauce_scores (
  id uuid primary key default gen_random_uuid(),
  judge_id uuid references public.judges(id) on delete cascade,
  chip_number text not null,
  score numeric not null check (score >= 0),
  created_at timestamptz not null default now()
);

-- Enable RLS
alter table public.sauce_scores enable row level security;

-- Read for everyone
create policy if not exists sauce_scores_select_all 
  on public.sauce_scores for select using (true);

-- Allow inserts
create policy if not exists sauce_scores_insert_all 
  on public.sauce_scores for insert with check (true);

-- Index for performance
create index if not exists idx_sauce_scores_judge_chip 
  on public.sauce_scores (judge_id, chip_number);
