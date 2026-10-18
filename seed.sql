-- Run after schema.sql on a fresh database.
-- Course data comes from the club's published scorecards
-- (realclubdegolfelprat.com, retrieved 13 Sep 2026). Tee times from the
-- Barcelona Golf Travel booking, ref 2440. Handicap indexes are guesses -
-- fix them in Admin before the trip.

-- The trip roster: Gamlir (born up to Oct 1963) v Ungir. Handicap indexes are
-- guesses - fix them in Admin before the trip.
insert into players (name, team, slot, handicap_index) values
  ('Stebbi','A',1,14.7), ('Gummi H','A',2,10.2), ('Gummi J','A',3,13.5), ('Benni','A',4,17.3),
  ('Garðar','A',5,24.2), ('Siggi','A',6,20.4), ('Guðbjörn','A',7,7.8), ('Valdi','A',8,8.9),
  ('Andri','B',1,12.4), ('Steini','B',2,18.1), ('Daði','B',3,19.8), ('Elliði','B',4,14.2),
  ('Kiddi','B',5,9.6), ('Jón Ingi','B',6,15.0), ('Jón Þór','B',7,11.5), ('Knútur','B',8,16.4);

insert into courses (name, par) values
  ('Amarillo (Yellow)', 72),
  ('Rosa (Pink)', 72);

insert into course_holes (course_id, hole, par, stroke_index)
select c.id, v.hole, v.par, v.si
from courses c,
  (values (1,4,3),(2,3,17),(3,4,15),(4,5,13),(5,4,9),(6,3,5),(7,4,7),(8,4,1),(9,5,11),
          (10,4,4),(11,5,16),(12,3,14),(13,4,8),(14,4,12),(15,4,10),(16,5,6),(17,3,18),(18,4,2))
  as v(hole, par, si)
where c.name = 'Amarillo (Yellow)';

insert into course_holes (course_id, hole, par, stroke_index)
select c.id, v.hole, v.par, v.si
from courses c,
  (values (1,5,9),(2,4,3),(3,3,17),(4,4,11),(5,4,13),(6,3,5),(7,4,7),(8,4,1),(9,5,15),
          (10,5,4),(11,3,16),(12,4,8),(13,3,12),(14,4,10),(15,4,18),(16,4,6),(17,4,2),(18,5,14))
  as v(hole, par, si)
where c.name = 'Rosa (Pink)';

-- Men's ratings from the RFEG (the handicapping authority), retrieved 13 Sep 2026.
insert into tees (course_id, name, course_rating, slope)
select c.id, t.name, t.cr, t.slope
from courses c,
  (values ('Blancas', 73.7, 135), ('Amarillas', 71.5, 131),
          ('Azules', 69.1, 124), ('Rojas', 67.1, 120)) as t(name, cr, slope)
where c.name = 'Amarillo (Yellow)';

insert into tees (course_id, name, course_rating, slope)
select c.id, t.name, t.cr, t.slope
from courses c,
  (values ('Blancas', 74.4, 146), ('Amarillas', 72.6, 143),
          ('Azules', 69.5, 133), ('Rojas', 68.1, 129)) as t(name, cr, slope)
where c.name = 'Rosa (Pink)';

-- Booked schedule: Amarillo Thu/Fri PM/Sat, Rosa Fri AM/Sun.
with pick as (
  select r.idx,
         (select id from courses where name = c.cname) as cid,
         (select t.id from tees t join courses cc on cc.id = t.course_id
           where cc.name = c.cname and t.name = 'Amarillas') as tid,
         c.st
  from rounds r
  join (values
    (1, 'Amarillo (Yellow)', time '11:05'),
    (2, 'Rosa (Pink)',       time '08:00'),
    (3, 'Amarillo (Yellow)', time '13:05'),
    (4, 'Amarillo (Yellow)', time '13:55'),
    (5, 'Rosa (Pink)',       time '13:20')
  ) as c(idx, cname, st) on c.idx = r.idx
)
update rounds r set course_id = p.cid, tee_id = p.tid, start_time = p.st
from pick p where p.idx = r.idx;

insert into info_pages (slug, title, body, sort) values
  ('travel','Getting there','El Prat is in Terrassa, about 30 minutes northwest of central Barcelona at Plans de Bonvilar 17. Club phone +34 937 281 000. Taxis take roughly 25 minutes in the morning, longer coming back through rush hour.',1),
  ('schedule','The schedule','- **Thu 8 Oct 11:05** Amarillo - Roommates Round
- **Fri 9 Oct 08:00** Rosa - Cup fourball R2
- **Fri 9 Oct 13:05** Amarillo - Cup fourball R3 (36-hole day, eat when you can)
- **Sat 10 Oct 13:55** Amarillo - Cup SINGLES, the decider
- **Sun 11 Oct 13:20** Rosa - Individual round',2),
  ('format','The format','# Herbergjakeppni (R1)
Better ball Stableford per pair - each hole counts the better of the two scores. Separate prize, and every man''s own round still counts in the individual race.

# The cup (16 points, 8.5 wins)
- **R2-R3 fourball:** highest Stableford points wins the hole; if the best scores are level, the partners decide; level again and the hole is halved. 18th counts double.
- **R4 singles:** eight 1v1 matches, higher points wins the hole, level halves. 18th counts double.
- Every match plays all 18 holes. Tie at 8-8 goes to aggregate hole points.

# The individual race
All five rounds count, plain Stableford, **best four of five**. Round 5 counts here only - no team points on Sunday.',3),
  ('dress','Dress code','Collared shirt, no denim, soft spikes. The clubhouse asks for smart casual after the round.',4);
