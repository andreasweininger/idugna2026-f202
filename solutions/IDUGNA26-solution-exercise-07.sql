SET SCHEMA IDUGNA26;

-- Query to explain and time (the metric MUST be COSINE to match the index)
SELECT l.listing_id,
       VECTOR_DISTANCE(l.desc_embedding, q.query_embedding, COSINE) AS dist
FROM   listing l, search_query q
WHERE  q.query_id = 1
ORDER  BY VECTOR_DISTANCE(l.desc_embedding, q.query_embedding, COSINE)
FETCH FIRST 10 ROWS ONLY;

