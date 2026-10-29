SET SCHEMA IDUGNA26;

-- 2a

SELECT COUNT(*) AS keyword_hits
FROM   listing
WHERE  LOWER(description) LIKE '%fuel efficient%'
   OR  LOWER(description) LIKE '%good gas mileage%';

-- 2b

SELECT l.listing_id, l.fuel_type, l.price,
       VECTOR_DISTANCE(l.desc_embedding, q.query_embedding, COSINE) AS dist,
       SUBSTR(l.description, 1, 100) AS descr
FROM   listing l, search_query q
WHERE  q.query_id = 1
ORDER  BY dist
FETCH FIRST 10 ROWS ONLY;

-- 2c

WITH top10 AS (
  SELECT l.listing_id, l.description
  FROM   listing l, search_query q
  WHERE  q.query_id = 1
  ORDER  BY VECTOR_DISTANCE(l.desc_embedding, q.query_embedding, COSINE)
  FETCH FIRST 10 ROWS ONLY
)
SELECT listing_id, SUBSTR(description, 1, 120) AS descr
FROM   top10
WHERE  LOWER(description) NOT LIKE '%fuel efficient%'
AND    LOWER(description) NOT LIKE '%good gas mileage%';

