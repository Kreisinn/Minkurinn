-- Real handicap indexes, 15 Sep 2026. Rúnar's 14.0 goes on Andri, who is
-- his ghost today - REMEMBER to set Andri's real index after the test.
-- Kiddi's index was not in the list and keeps its placeholder (9.6).

update players set handicap_index = v.hcp
from (values
  ('Stebbi', 7.7), ('Guðbjörn', 17.5), ('Steini', 7.9), ('Benni', 10.2),
  ('Garðar', 20.4), ('Elliði', 16.3), ('Jón Ingi', 12.4), ('Daði', 8.6),
  ('Gummi J', 21.2), ('Jón Þór', 2.1), ('Knútur', 19.8), ('Siggi', 21.7),
  ('Valdi', 20.0), ('Andri', 14.0)
) as v(name, hcp)
where players.name = v.name;
