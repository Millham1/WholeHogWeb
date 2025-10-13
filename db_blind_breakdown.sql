-- Table to store per-category blind scores
create table if not exists blind_scores_breakdown (
  id bigserial primary key,
  chip_number text not null,
  judge text not null,
  category_key text not null,
  category_label text,
  score numeric not null,
  created_at timestamp with time zone default now()
);

-- Optional: make chip -> team link enforceable if teams.chip_number is unique
-- alter table blind_scores_breakdown
--   add constraint blind_cat_chip_fk
--   foreign key (chip_number) references teams(chip_number) on delete cascade;

-- View: per-team, per-category totals for reporting
create or replace view blind_team_category_totals as
select
  coalesce(t.team_name, '(Unknown Team)') as team_name,
  b.category_key,
  max(b.category_label) as category_label,
  sum(b.score) as total_score,
  count(*) as entries
from blind_scores_breakdown b
left join teams t
  on upper(t.chip_number::text) = upper(b.chip_number::text)
group by coalesce(t.team_name, '(Unknown Team)'), b.category_key
order by team_name, category_key;

-- View: per-team total across all blind categories (for rank)
create or replace view blind_team_totals as
select
  coalesce(t.team_name, '(Unknown Team)') as team_name,
  sum(b.score) as total_score,
  count(*) as entries
from blind_scores_breakdown b
left join teams t
  on upper(t.chip_number::text) = upper(b.chip_number::text)
group by coalesce(t.team_name, '(Unknown Team)')
order by total_score desc nulls last;
