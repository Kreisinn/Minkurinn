-- TEST RUN: Grafarholtsvöllur, 15 Sep 2026.
-- Adds the course (official GSÍ card), points round 1 at it, and creates
-- today's four groups with the real tee times and pair assignments.
-- Run restore-after-test.sql afterwards to put round 1 back to El Prat.

insert into courses (name, par) values ('Grafarholt', 71)
on conflict (name) do nothing;

insert into course_holes (course_id, hole, par, stroke_index)
select c.id, v.hole, v.par, v.si
from courses c,
  (values (1,4,15),(2,3,17),(3,4,3),(4,5,11),(5,4,1),(6,3,5),(7,4,13),(8,4,9),(9,4,7),
          (10,4,8),(11,3,6),(12,5,12),(13,4,16),(14,4,18),(15,5,2),(16,4,4),(17,3,10),(18,4,14))
  as v(hole, par, si)
where c.name = 'Grafarholt'
on conflict do nothing;

-- Men's ratings, GSÍ vallarmat 2025. Icelandic tees are named by length.
insert into tees (course_id, name, course_rating, slope)
select c.id, t.name, t.cr, t.slope
from courses c,
  (values ('63', 73.0, 139), ('57', 69.4, 127), ('52', 67.0, 123), ('46', 65.0, 113))
  as t(name, cr, slope)
where c.name = 'Grafarholt'
on conflict do nothing;

-- Round 1 becomes today's test: Grafarholt, tee 57 default, first group 14:18.
update rounds set
  course_id  = (select id from courses where name = 'Grafarholt'),
  tee_id     = (select t.id from tees t join courses c on c.id = t.course_id
                 where c.name = 'Grafarholt' and t.name = '57'),
  play_date  = '2026-09-15',
  start_time = '14:18'
where idx = 1;

-- Today's groups and pairs. Pairs are guessed as seating order (1&2, 3&4) -
-- change them in Admin if the pairings are different.
delete from matches where round_id = (select id from rounds where idx = 1);

with r as (select id from rounds where idx = 1),
ins as (
  insert into matches (round_id, slot, tee_time)
  select r.id, s.slot, s.tt
  from r, (values (1, time '14:18'), (2, time '14:36'),
                  (3, time '14:54'), (4, time '15:12')) as s(slot, tt)
  returning id, slot
)
insert into match_players (match_id, player_id, pair)
select ins.id, p.id, a.pair
from ins
join (values
  (1,'Valdi',1),   (1,'Knútur',1),   (1,'Siggi',2),    (1,'Gummi J',2),
  (2,'Garðar',1),  (2,'Jón Ingi',1), (2,'Guðbjörn',2), (2,'Daði',2),
  (3,'Kiddi',1),   (3,'Steini',1),   (3,'Stebbi',2),   (3,'Jón Þór',2),
  (4,'Elliði',1),  (4,'Benni',1),    (4,'Andri',2)
) as a(slot, name, pair) on a.slot = ins.slot
join players p on p.name = a.name;
