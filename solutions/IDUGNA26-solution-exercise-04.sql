SET SCHEMA IDUGNA26;

-- 4a

SELECT d.dealer_id, d.dealer_name, d.city, COUNT(*) AS rust_notes
FROM   inspection_note n
JOIN   search_query q ON q.query_id = 5
JOIN   listing l      ON l.listing_id = n.listing_id
JOIN   dealer d       ON d.dealer_id = l.dealer_id
WHERE  VECTOR_DISTANCE(n.note_embedding, q.query_embedding, COSINE) < 0.45
GROUP  BY d.dealer_id, d.dealer_name, d.city
ORDER  BY rust_notes DESC
FETCH FIRST 5 ROWS ONLY;

-- 4b

WITH bad AS (
  SELECT r.model_id, r.model_year, COUNT(*) AS complaints
  FROM   owner_review r
  JOIN   search_query q ON q.query_id = 6
  WHERE  VECTOR_DISTANCE(r.review_embedding, q.query_embedding, COSINE) < 0.45
  GROUP  BY r.model_id, r.model_year
  HAVING COUNT(*) >= 5
)
SELECT m.make, m.model, l.model_year, l.listing_id, l.price, b.complaints
FROM   bad b
JOIN   listing l   ON l.model_id = b.model_id AND l.model_year = b.model_year
JOIN   car_model m ON m.model_id = l.model_id
WHERE  l.status = 'AVAILABLE'
ORDER  BY b.complaints DESC, l.listing_id;

-- 4c: the relational conditions cut the pair list down before any vector is compared

SELECT a.listing_id AS id_a, b.listing_id AS id_b, a.dealer_id AS dealer_a, b.dealer_id AS dealer_b,
       VECTOR_DISTANCE(a.desc_embedding, b.desc_embedding, COSINE) AS dist
FROM   listing a
JOIN   listing b ON  b.model_id   = a.model_id
                 AND b.model_year = a.model_year
                 AND b.dealer_id <> a.dealer_id
                 AND b.listing_id > a.listing_id
                 AND ABS(b.mileage - a.mileage) <= 0.02 * a.mileage
WHERE  VECTOR_DISTANCE(a.desc_embedding, b.desc_embedding, COSINE) < 0.1
ORDER  BY dist;

