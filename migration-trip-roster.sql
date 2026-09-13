-- Migration: the actual trip roster and teams (Gamlir v Ungir).
-- Run ONLY on an existing database. Fresh installs get this from schema.sql
-- and seed.sql.
--
-- WARNING: this replaces all players, which requires deleting all matches -
-- and any scores entered with them. Run it before the trip, not during.
-- Afterwards: regenerate pairings for rounds 2-5 in Admin, assign the round 1
-- roommate pairs by hand, and correct the guessed handicap indexes.

update teams set name = 'Gamlir' where key = 'A';
update teams set name = 'Ungir'  where key = 'B';

delete from matches;   -- cascades match_players and scores
delete from players;

insert into players (name, team, slot, handicap_index) values
  ('Stebbi','A',1,14.7), ('Gummi H','A',2,10.2), ('Gummi J','A',3,13.5), ('Benni','A',4,17.3),
  ('Garðar','A',5,24.2), ('Siggi','A',6,20.4), ('Guðbjörn','A',7,7.8), ('Valdi','A',8,8.9),
  ('Andri','B',1,12.4), ('Steini','B',2,18.1), ('Daði','B',3,19.8), ('Elliði','B',4,14.2),
  ('Kiddi','B',5,9.6), ('Jón Ingi','B',6,15.0), ('Jón Þór','B',7,11.5), ('Knútur','B',8,16.4);
