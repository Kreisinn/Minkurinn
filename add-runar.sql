-- TEST ONLY: adds Rúnar as a real 15th player (temporary 9th Ungir slot)
-- and seats him in group 4, pair 2, alongside ghost Andri.
-- Run AFTER test-grafarholt.sql. restore-after-test.sql removes him again.

-- Widen the 8-per-team slot limit to fit a guest.
alter table players drop constraint if exists players_slot_check;
alter table players add constraint players_slot_check check (slot between 1 and 9);

insert into players (name, team, slot, handicap_index)
values ('Rúnar', 'B', 9, 14.0)
on conflict (team, slot) do nothing;

-- Andri is the ghost now, so his index goes back to his own number.
update players set handicap_index = 12.4 where name = 'Andri';

-- Seat Rúnar in group 4 as Andri's partner (pair 2 v Elliði & Benni).
insert into match_players (match_id, player_id, pair)
select m.id, p.id, 2
from matches m
join rounds r on r.id = m.round_id and r.idx = 1
join players p on p.name = 'Rúnar'
where m.slot = 4
on conflict do nothing;
