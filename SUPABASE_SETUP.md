# Supabase Database Setup

This document describes the database schema required for the WholeHog Competition Web App.

## Required Tables

### 1. teams
```sql
create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  site_number text,
  chip_number text,
  affiliation text,
  created_at timestamptz not null default now()
);

alter table public.teams enable row level security;
create policy if not exists teams_select_all on public.teams for select using (true);
create policy if not exists teams_insert_all on public.teams for insert with check (true);
create policy if not exists teams_update_all on public.teams for update using (true);
```

### 2. judges
```sql
create table if not exists public.judges (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

alter table public.judges enable row level security;
create policy if not exists judges_select_all on public.judges for select using (true);
create policy if not exists judges_insert_all on public.judges for insert with check (true);
```

### 3. onsite_scores
```sql
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

alter table public.onsite_scores enable row level security;
create policy if not exists onsite_scores_select_all on public.onsite_scores for select using (true);
create policy if not exists onsite_scores_insert_all on public.onsite_scores for insert with check (true);

create index if not exists idx_onsite_scores_team on public.onsite_scores (team_id);
create index if not exists idx_onsite_scores_judge on public.onsite_scores (judge_id);
```

### 4. blind_taste
```sql
create table if not exists public.blind_taste (
  id uuid primary key default gen_random_uuid(),
  judge_id text not null,
  chip_number integer not null,
  score_appearance numeric,
  score_tenderness numeric,
  score_flavor numeric,
  score_total numeric not null,
  created_at timestamptz not null default now()
);

-- Uniqueness: a judge may score a chip only once
create unique index if not exists blind_taste_judge_chip_uniq
  on public.blind_taste (judge_id, chip_number);

alter table public.blind_taste enable row level security;
create policy if not exists blind_taste_select_all on public.blind_taste for select using (true);
create policy if not exists blind_taste_insert_anon on public.blind_taste for insert with check (true);
```

### 5. sauce_scores
```sql
create table if not exists public.sauce_scores (
  id uuid primary key default gen_random_uuid(),
  judge_id uuid references public.judges(id) on delete cascade,
  chip_number text not null,
  score numeric not null check (score >= 0),
  created_at timestamptz not null default now()
);

alter table public.sauce_scores enable row level security;
create policy if not exists sauce_scores_select_all on public.sauce_scores for select using (true);
create policy if not exists sauce_scores_insert_all on public.sauce_scores for insert with check (true);

create index if not exists idx_sauce_scores_judge_chip on public.sauce_scores (judge_id, chip_number);
```

## Setup Instructions

1. Log into your Supabase project dashboard
2. Go to the SQL Editor
3. Run each of the CREATE TABLE statements above in order
4. Verify that Row Level Security (RLS) is enabled for each table
5. Verify that the policies are created correctly

## Configuration

The app uses the credentials in `supabase-config.js`:
- URL: https://wiolulxxfyetvdpnfusq.supabase.co
- Anon Key: (stored in supabase-config.js)

## Testing

After setup, test each page:
1. **Landing Page** (`landing.html`) - Add teams and judges
2. **On-Site Scoring** (`onsite.html`) - Load teams/judges and save scores
3. **Blind Taste** (`blind-taste.html`) - Save blind taste scores
4. **Sauce Tasting** (`sauce.html`) - Save sauce scores

All data should persist to Supabase and be visible across page reloads and browser sessions.
