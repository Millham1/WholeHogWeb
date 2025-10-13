-- Create table for blind taste scores (idempotent)
create table if not exists blind_scores (
  id bigserial primary key,
  chip_number text not null,
  judge text not null,
  score numeric not null,
  created_at timestamp with time zone default now()
);

-- Optional FK if teams.chip_number is unique:
-- alter table blind_scores
--   add constraint blind_scores_chip_fk
--   foreign key (chip_number) references teams(chip_number) on delete cascade;
