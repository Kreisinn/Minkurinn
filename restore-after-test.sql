-- Run after the Grafarholt test to put round 1 back to the real trip:
-- deletes the test groups and their scores, restores El Prat Amarillo,
-- the 8 Oct date and the 11:05 start. The Grafarholt course stays in the
-- database (harmless, and handy if you test again); uncomment the last
-- line to remove it completely.

delete from matches where round_id = (select id from rounds where idx = 1);

update rounds set
  course_id  = (select id from courses where name = 'Amarillo (Yellow)'),
  tee_id     = (select t.id from tees t join courses c on c.id = t.course_id
                 where c.name = 'Amarillo (Yellow)' and t.name = 'Amarillas'),
  play_date  = '2026-10-08',
  start_time = '11:05'
where idx = 1;

-- delete from courses where name = 'Grafarholt';
