SET SCHEMA idugna26;

-- =====================================================================
-- AutoNova lab 
-- Run by after IDUG26-create-tables.sql.
-- Small reference data
-- =====================================================================

-- Colors with RGB values. Visually similar colors get similar RGB values,
-- which is what makes "light blue" close to "blue" in Exercise 5.
INSERT INTO color_ref (color_name, r, g, b) VALUES
  ('black',       0,   0,   0),
  ('white',     255, 255, 255),
  ('silver',    192, 192, 192),
  ('gray',      128, 128, 128),
  ('charcoal',   54,  69,  79),
  ('red',       200,  16,  46),
  ('burgundy',  128,   0,  32),
  ('orange',    255, 140,   0),
  ('yellow',    255, 215,   0),
  ('gold',      212, 175,  55),
  ('green',      34, 139,  34),
  ('dark green',  0, 100,   0),
  ('blue',       30,  80, 200),
  ('light blue',135, 206, 235),
  ('navy',        0,   0, 128),
  ('teal',        0, 128, 128),
  ('brown',     101,  67,  33),
  ('beige',     245, 245, 220),
  ('tan',       210, 180, 140),
  ('purple',    128,   0, 128);

-- Default weights for the multi-column feature vector (Exercise 5).
-- Exactly one row. 0 = "don't care", higher = more important.
INSERT INTO feat_weight
  (w_color, w_year, w_mileage, w_price, w_fuel, w_trans, w_owners, w_body)
VALUES
  (1.00,    1.00,   0.50,     0.50,    0.50,   0.25,    0.25,     1.00);

COMMIT;

SELECT * FROM color_ref;
