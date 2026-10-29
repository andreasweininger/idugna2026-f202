SET SCHEMA IDUGNA26;

-- 5a

INSERT INTO car_request
  (request_id, color, model_year, mileage, price, fuel_type, transmission, owners, body_type)
VALUES (1, 'blue', 2020, 45000, 24000, 'HYBRID', 'AUTOMATIC', 1, 'SUV');
COMMIT;

-- 5b: expect 16 dimensions

SELECT src, id, VECTOR_DIMENSION_COUNT(feat) AS dims, VECTOR_SERIALIZE(feat) AS feat_txt
FROM   v_car_feat
WHERE  (src = 'R' AND id = 1) OR (src = 'L' AND id IN (1, 2, 3));

-- 5c

SELECT l.listing_id, l.color, l.model_year, l.mileage, l.price, l.fuel_type,
       VECTOR_DISTANCE(lf.feat, rf.feat, EUCLIDEAN) AS dist
FROM   v_car_feat lf
JOIN   v_car_feat rf ON rf.src = 'R' AND rf.id = 1
JOIN   listing l     ON l.listing_id = lf.id
WHERE  lf.src = 'L'
AND    l.status = 'AVAILABLE'
ORDER  BY dist
FETCH FIRST 25 ROWS ONLY;

-- 5d: weights (the table has exactly one row, so no WHERE)

UPDATE feat_weight SET w_color = 3;       -- 1. color first
-- rerun 5c, then:
UPDATE feat_weight SET w_color = 1, w_year = 4;   -- 2. exact year
-- rerun 5c, then:
UPDATE feat_weight SET w_color = 0, w_year = 1;   -- 3. color does not matter
-- rerun 5c, then restore the defaults:
UPDATE feat_weight
SET    w_color = 1.00, w_year = 1.00, w_mileage = 0.50, w_price = 0.50,
       w_fuel  = 0.50, w_trans = 0.25, w_owners = 0.25, w_body = 1.00;
COMMIT;

-- 5e
-- =====================================================================
-- AutoNova lab - Exercise 5e solution (INSTRUCTOR ONLY)
-- Adds accident_free as a 17th dimension of the multi-column feature vector.
--
-- Not run against a real Db2 12.1.5 server yet. Dry-run before the session.
--
-- Three things change compared with 03_views.sql:
--   1. FEAT_WEIGHT gets a new column W_ACC
--   2. V_CAR_SCALED gets a new column AC in BOTH branches of the UNION ALL
--   3. V_CAR_FEAT gets a 17th element X17 and VECTOR(..., 17, FLOAT32)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Weight for the new column (the single existing row gets 0.50)
-- ---------------------------------------------------------------------
ALTER TABLE feat_weight ADD COLUMN w_acc DECIMAL(4,2) NOT NULL DEFAULT 0.50;

-- ---------------------------------------------------------------------
-- 2. Recreate the views. Drop the dependent view first.
-- ---------------------------------------------------------------------
DROP VIEW v_car_feat;
DROP VIEW v_car_scaled;

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
       m.body_type                  AS body,
       CASE l.accident_free WHEN 'Y' THEN 1.0E0 ELSE 0.0E0 END AS ac   -- NEW
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
       q.body_type,
       1.0E0                                                            -- NEW: the buyer wants an accident-free car
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
                  || RTRIM(CHAR(x15)) || ',' || RTRIM(CHAR(x16)) || ','
                  || RTRIM(CHAR(x17)) || ']',                              -- NEW element
              17, FLOAT32) AS feat                                         -- NEW dimension
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
         DECIMAL(CASE s.body WHEN 'COUPE'     THEN w.w_body ELSE 0 END, 9, 6) AS x16,
         DECIMAL(s.ac * w.w_acc,     9, 6) AS x17    -- NEW: accident-free
  FROM   v_car_scaled s
  CROSS  JOIN feat_weight w
) t;

-- ---------------------------------------------------------------------
-- 3. Check: expect 17 dimensions for requests and listings
-- ---------------------------------------------------------------------
SELECT src, id, VECTOR_DIMENSION_COUNT(feat) AS dims
FROM   v_car_feat
WHERE  (src = 'R' AND id = 1) OR (src = 'L' AND id IN (1, 2, 3));

-- Rerun the Exercise 5c query. Listings with accident_free = 'N' must now
-- rank lower than otherwise identical listings with accident_free = 'Y'.
-- Set w_acc = 0 to switch the new dimension off:
--   UPDATE feat_weight SET w_acc = 0;

-- ---------------------------------------------------------------------
-- 4. Go back to the 16-dimension version
-- ---------------------------------------------------------------------
-- DROP VIEW v_car_feat;
-- DROP VIEW v_car_scaled;
-- ALTER TABLE feat_weight DROP COLUMN w_acc;
-- REORG TABLE feat_weight;       -- required after DROP COLUMN
-- then re-run the two CREATE VIEW statements from 03_views.sql

UPDATE listing
SET    attr_embedding = TO_EMBEDDING('color: ' || color
                                     || '; model year: ' || RTRIM(CHAR(model_year))
                                     || '; fuel: ' || fuel_type
                                     || '; transmission: ' || transmission
                                     USING IDUGNA26.local_embedder)
WHERE  listing_id <= 100;
COMMIT;

SELECT l.listing_id, l.color, l.model_year, l.fuel_type,
       VECTOR_DISTANCE(l.attr_embedding, q.query_embedding, COSINE) AS dist
FROM   listing l, search_query q
WHERE  q.query_id = 110
AND    l.attr_embedding IS NOT NULL
ORDER  BY dist
FETCH FIRST 20 ROWS ONLY;

-- 5g

WITH feat_rank AS (
  SELECT lf.id AS listing_id,
         ROW_NUMBER() OVER (ORDER BY VECTOR_DISTANCE(lf.feat, rf.feat, EUCLIDEAN)) AS rk
  FROM   v_car_feat lf
  JOIN   v_car_feat rf ON rf.src = 'R' AND rf.id = 1
  JOIN   listing l     ON l.listing_id = lf.id AND l.status = 'AVAILABLE'
  WHERE  lf.src = 'L'
), desc_rank AS (
  SELECT l.listing_id,
         ROW_NUMBER() OVER (ORDER BY VECTOR_DISTANCE(l.desc_embedding, q.query_embedding, COSINE)) AS rk
  FROM   listing l, search_query q
  WHERE  q.query_id = 102
  AND    l.status = 'AVAILABLE'
)
SELECT l.listing_id, l.color, l.model_year, l.price,
       f.rk AS rank_feat, d.rk AS rank_desc,
       1.0 / (60 + f.rk) + 1.0 / (60 + d.rk) AS rrf_score
FROM   feat_rank f
JOIN   desc_rank d ON d.listing_id = f.listing_id
JOIN   listing l   ON l.listing_id = f.listing_id
ORDER  BY rrf_score DESC
FETCH FIRST 10 ROWS ONLY;


