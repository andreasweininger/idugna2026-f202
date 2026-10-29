SET SCHEMA IDUGNA26;

-- 3a

SELECT l.listing_id, l.status, l.price,
       VECTOR_DISTANCE(l.desc_embedding, q.query_embedding, COSINE) AS dist,
       SUBSTR(l.description, 1, 80) AS descr
FROM   listing l
JOIN   customer c     ON c.customer_id = 77
JOIN   search_query q ON q.query_id = 1
WHERE  l.status = 'AVAILABLE'
AND    l.price <= c.budget_max
ORDER  BY dist
FETCH FIRST 10 ROWS ONLY;

-- 3b: cut-off in a derived table, so the distance is computed once

SELECT *
FROM (
  SELECT l.listing_id, l.price,
         VECTOR_DISTANCE(l.desc_embedding, q.query_embedding, COSINE) AS dist,
         SUBSTR(l.description, 1, 80) AS descr
  FROM   listing l
  JOIN   customer c     ON c.customer_id = 77
  JOIN   search_query q ON q.query_id = 1
  WHERE  l.status = 'AVAILABLE'
  AND    l.price <= c.budget_max
) t
WHERE dist < 0.35
ORDER BY dist;

-- 3c: distance to the dealer in miles (flat-earth approximation, fine below ~200 miles)

SELECT *
FROM (
  SELECT l.listing_id, l.price, d.city,
         VECTOR_DISTANCE(l.desc_embedding, q.query_embedding, COSINE) AS dist,
         69.0 * SQRT(POWER(d.latitude - c.home_lat, 2)
                   + POWER(COS(RADIANS(c.home_lat)) * (d.longitude - c.home_lon), 2)) AS miles
  FROM   listing l
  JOIN   dealer d       ON d.dealer_id = l.dealer_id
  JOIN   customer c     ON c.customer_id = 77
  JOIN   search_query q ON q.query_id = 1
  WHERE  l.status = 'AVAILABLE'
  AND    l.price <= c.budget_max
) t
WHERE dist < 0.35
AND   miles <= 100
ORDER BY dist;

-- 3d: the text claims "no accidents", the authoritative flag says otherwise

SELECT l.listing_id, l.accident_free,
       VECTOR_DISTANCE(l.desc_embedding, q.query_embedding, COSINE) AS dist,
       SUBSTR(l.description, 1, 120) AS descr
FROM   listing l, search_query q
WHERE  q.query_id = 4
AND    l.accident_free = 'N'
ORDER  BY dist
FETCH FIRST 30 ROWS ONLY;