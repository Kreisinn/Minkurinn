-- Migration: per-player tee selection.
-- Run this ONLY on a database created before this change, then re-run
-- courses-elprat.sql (it now loads all four men's tee sets per course, with
-- the RFEG official ratings). Fresh installs get everything from schema.sql
-- and seed.sql and don't need this file.

alter table players
  add column if not exists tee_name text not null default 'Amarillas';

-- Set forward tees for individual players like this:
-- update players set tee_name = 'Azules' where name in ('Garðar', 'Rúni Júl');
