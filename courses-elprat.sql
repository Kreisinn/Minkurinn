-- Real course data for Amarillo and Rosa, taken from the club's published
-- scorecards (realclubdegolfelprat.com, retrieved 13 Sep 2026), plus the booked
-- tee times from Barcelona Golf Travel (ref 2440).
--
-- Run this on an existing database. Fresh installs get the same data from the
-- updated seed.sql and must NOT run this file.
-- Safe to re-run; it replaces all course data. Scores reference matches, not
-- courses, so nothing entered is lost.

alter table rounds add column if not exists start_time time;

update rounds set course_id = null, tee_id = null;
delete from courses;

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
