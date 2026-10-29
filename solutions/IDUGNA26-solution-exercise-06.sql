SET SCHEMA IDUGNA26;

-- 6a

SELECT l.listing_id, l.model_year, l.price,
       VECTOR_DISTANCE(l.desc_embedding, s.desc_embedding, COSINE) AS dist,
       SUBSTR(l.description, 1, 80) AS descr
FROM   listing s
JOIN   listing l ON l.listing_id <> s.listing_id AND l.status = 'AVAILABLE'
WHERE  s.listing_id = 1
ORDER  BY dist
FETCH FIRST 10 ROWS ONLY;

-- 6b: average distance to all favorites

SELECT l.listing_id, l.price, l.model_year,
       AVG(VECTOR_DISTANCE(l.desc_embedding, fl.desc_embedding, COSINE)) AS avg_dist
FROM   customer c
JOIN   favorite f  ON f.customer_id = c.customer_id
JOIN   listing fl  ON fl.listing_id = f.listing_id
JOIN   listing l   ON l.status = 'AVAILABLE' AND l.price <= c.budget_max
WHERE  c.customer_id = 77
AND    l.listing_id NOT IN (SELECT listing_id FROM favorite WHERE customer_id = 77)
GROUP  BY l.listing_id, l.price, l.model_year
ORDER  BY avg_dist
FETCH FIRST 10 ROWS ONLY;

-- 6c: first insert listing 9001 (pattern in 04_staging_and_load.sql, Step 3c), then:

SELECT c.customer_id, c.customer_name, s.search_text, t.dist
FROM (
  SELECT s.saved_search_id,
         VECTOR_DISTANCE(s.search_embedding, l.desc_embedding, COSINE) AS dist
  FROM   listing l
  JOIN   saved_search s ON s.max_price   >= l.price
                       AND s.max_mileage >= l.mileage
                       AND s.min_year    <= l.model_year
  WHERE  l.listing_id = 9001
) t
JOIN saved_search s ON s.saved_search_id = t.saved_search_id
JOIN customer c     ON c.customer_id = s.customer_id
WHERE t.dist < 0.40
ORDER BY t.dist;