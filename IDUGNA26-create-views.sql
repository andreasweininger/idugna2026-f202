SET SCHEMA IDUGNA26;

-- =====================================================================
-- AutoNova lab - 03_views.sql
-- Run after IDUGNA26-insert-reference-data.sql
--
-- Multi-column similarity (Exercise 5): the relational columns of a listing
-- (color, year, mileage, price, fuel, transmission, owners, body type) are
-- turned into one numeric feature vector, so that VECTOR_DISTANCE can rank
-- "similar" cars instead of only exactly matching ones.
--
--   v_car_scaled : every column scaled so that "1 unit" is a comparable
--                  amount of difference, not yet weighted
--   v_car_feat   : scaled values x weights from FEAT_WEIGHT -> VECTOR(16)
--
-- Both views contain listings (src = 'L') and buyer requests (src = 'R')
-- so that both sides of the comparison are encoded by the same logic.
--
-- To add a column: add one scaled column in v_car_scaled, one weight in
-- FEAT_WEIGHT, one element in v_car_feat, and increase the VECTOR dimension.
-- =====================================================================

CREATE VIEW v_car_scaled AS
SELECT 'L'                          AS src,
       l.listing_id                 AS id,
       c.r / 255.0E0                AS r,
       c.g / 255.0E0                AS g,
       c.b / 255.0E0                AS b,
       (l.model_year - 2010) / 10.0E0 AS yr,        -- 1 year  = 0.1
       l.mileage / 100000.0E0       AS mi,          -- 10k mi  = 0.1
       l.price / 30000.0E0          AS pr,          -- $3000   = 0.1
       CASE l.fuel_type WHEN 'HYBRID' THEN 0.5E0
                        WHEN 'PHEV'   THEN 0.75E0
                        WHEN 'EV'     THEN 1.0E0
                        ELSE 0.0E0 END AS fu,       -- degree of electrification
       CASE l.transmission WHEN 'MANUAL' THEN 1.0E0 ELSE 0.0E0 END AS tr,
       LEAST(l.owners, 4) / 4.0E0   AS ow,
       m.body_type                  AS body
FROM   listing l
JOIN   car_model m ON m.model_id   = l.model_id
JOIN   color_ref c ON c.color_name = l.color
UNION ALL
SELECT 'R',
       q.request_id,
       c.r / 255.0E0,
       c.g / 255.0E0,
       c.b / 255.0E0,
       (q.model_year - 2010) / 10.0E0,
       q.mileage / 100000.0E0,
       q.price / 30000.0E0,
       CASE q.fuel_type WHEN 'HYBRID' THEN 0.5E0
                        WHEN 'PHEV'   THEN 0.75E0
                        WHEN 'EV'     THEN 1.0E0
                        ELSE 0.0E0 END,
       CASE q.transmission WHEN 'MANUAL' THEN 1.0E0 ELSE 0.0E0 END,
       LEAST(q.owners, 4) / 4.0E0,
       q.body_type
FROM   car_request q
JOIN   color_ref c ON c.color_name = q.color;

CREATE VIEW v_car_feat AS
SELECT src,
       id,
       VECTOR('[' || RTRIM(CHAR(x1))  || ',' || RTRIM(CHAR(x2))  || ','
                  || RTRIM(CHAR(x3))  || ',' || RTRIM(CHAR(x4))  || ','
                  || RTRIM(CHAR(x5))  || ',' || RTRIM(CHAR(x6))  || ','
                  || RTRIM(CHAR(x7))  || ',' || RTRIM(CHAR(x8))  || ','
                  || RTRIM(CHAR(x9))  || ',' || RTRIM(CHAR(x10)) || ','
                  || RTRIM(CHAR(x11)) || ',' || RTRIM(CHAR(x12)) || ','
                  || RTRIM(CHAR(x13)) || ',' || RTRIM(CHAR(x14)) || ','
                  || RTRIM(CHAR(x15)) || ',' || RTRIM(CHAR(x16)) || ']',
              16, FLOAT32) AS feat
FROM (
  SELECT s.src, s.id,
         DECIMAL(s.r  * w.w_color,   9, 6) AS x1,    -- color: R, G, B
         DECIMAL(s.g  * w.w_color,   9, 6) AS x2,
         DECIMAL(s.b  * w.w_color,   9, 6) AS x3,
         DECIMAL(s.yr * w.w_year,    9, 6) AS x4,
         DECIMAL(s.mi * w.w_mileage, 9, 6) AS x5,
         DECIMAL(s.pr * w.w_price,   9, 6) AS x6,
         DECIMAL(s.fu * w.w_fuel,    9, 6) AS x7,
         DECIMAL(s.tr * w.w_trans,   9, 6) AS x8,
         DECIMAL(s.ow * w.w_owners,  9, 6) AS x9,
         -- body type: one-hot, scaled by the body weight
         DECIMAL(CASE s.body WHEN 'SEDAN'     THEN w.w_body ELSE 0 END, 9, 6) AS x10,
         DECIMAL(CASE s.body WHEN 'SUV'       THEN w.w_body ELSE 0 END, 9, 6) AS x11,
         DECIMAL(CASE s.body WHEN 'TRUCK'     THEN w.w_body ELSE 0 END, 9, 6) AS x12,
         DECIMAL(CASE s.body WHEN 'HATCHBACK' THEN w.w_body ELSE 0 END, 9, 6) AS x13,
         DECIMAL(CASE s.body WHEN 'WAGON'     THEN w.w_body ELSE 0 END, 9, 6) AS x14,
         DECIMAL(CASE s.body WHEN 'MINIVAN'   THEN w.w_body ELSE 0 END, 9, 6) AS x15,
         DECIMAL(CASE s.body WHEN 'COUPE'     THEN w.w_body ELSE 0 END, 9, 6) AS x16
  FROM   v_car_scaled s
  CROSS  JOIN feat_weight w
) t;

-- Quick check after data is loaded (expect 16 dimensions):
SELECT id, VECTOR_DIMENSION_COUNT(feat), VECTOR_SERIALIZE(feat)
FROM   v_car_feat WHERE src = 'L' FETCH FIRST 3 ROWS ONLY;
