-- Run after schema.sql. Course data here is a placeholder: replace par and
-- stroke_index with the official card for each configuration before the trip.

insert into players (name, team, slot, handicap_index) values
  ('Andri','A',1,12.4), ('Steini','A',2,18.1), ('Kiddi','A',3,9.6), ('Gummi Bald','A',4,21.3),
  ('Jón Ingi','A',5,15.0), ('Guðbjörn','A',6,7.8), ('Garðar','A',7,24.2), ('Jón Þór','A',8,11.5),
  ('Stebbi','B',1,14.7), ('Gummi Hjalta','B',2,10.2), ('Daði','B',3,19.8), ('Knútur','B',4,16.4),
  ('Valdi','B',5,8.9), ('Rúni Júl','B',6,22.6), ('Jónas','B',7,13.1), ('Benni','B',8,17.3);

insert into courses (name, par) values ('Bosque + Arriba (Pink)', 72);

insert into course_holes (course_id, hole, par, stroke_index)
select c.id, v.hole, v.par, v.si
from courses c,
  (values (1,4,7),(2,5,11),(3,4,1),(4,3,15),(5,4,5),(6,4,9),(7,5,13),(8,3,17),(9,4,3),
          (10,4,8),(11,4,2),(12,3,16),(13,5,12),(14,4,4),(15,4,10),(16,3,18),(17,4,6),(18,5,14))
  as v(hole, par, si)
where c.name = 'Bosque + Arriba (Pink)';

insert into tees (course_id, name, course_rating, slope)
select id, 'White', 71.4, 132 from courses where name = 'Bosque + Arriba (Pink)';

update rounds set
  course_id = (select id from courses where name = 'Bosque + Arriba (Pink)'),
  tee_id    = (select id from tees    where name = 'White');

insert into info_pages (slug, title, body, sort) values
  ('travel','Getting there','El Prat is in Terrassa, about 30 minutes northwest of central Barcelona. Taxis from the hotel take roughly 25 minutes in the morning, longer coming back through rush hour.',1),
  ('format','The format','Four matches per round, two players from each team in every group. On each hole the highest Stableford points wins it. If the best scores are level, the partners decide. Level again and the hole is halved. The 18th counts double. Every match plays all 18 holes.',2),
  ('dress','Dress code','Collared shirt, no denim, soft spikes. The clubhouse asks for smart casual after the round.',3);
