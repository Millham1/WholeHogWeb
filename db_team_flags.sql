-- === Add flags to teams (idempotent) ===
alter table teams add column if not exists is_legion boolean default false;
alter table teams add column if not exists is_sons   boolean default false;

-- === Totals per team (by chip) ===
create or replace view team_totals as
select
  t.chip_number,
  t.team_name,
  t.site_number,
  coalesce(sum(s.score), 0) as total_score
from teams t
left join scores s
  on s.chip_number = t.chip_number
group by t.chip_number, t.team_name, t.site_number;

-- === Legion Team Winner (highest total among is_legion=true) ===
create or replace view legion_winner as
select tt.*
from team_totals tt
join teams t on t.chip_number = tt.chip_number
where coalesce(t.is_legion, false) is true
order by tt.total_score desc nulls last
limit 1;

-- === Sons Team Winner (highest total among is_sons=true) ===
create or replace view sons_winner as
select tt.*
from team_totals tt
join teams t on t.chip_number = tt.chip_number
where coalesce(t.is_sons, false) is true
order by tt.total_score desc nulls last
limit 1;
