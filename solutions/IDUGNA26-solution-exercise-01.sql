SET SCHEMA IDUGNA26;

-- 1a

SELECT VECTOR_DISTANCE(VECTOR('[1,0,0]', 3, FLOAT32), VECTOR('[0,1,0]', 3, FLOAT32), COSINE)    AS cos_orth,
       VECTOR_DISTANCE(VECTOR('[1,0,0]', 3, FLOAT32), VECTOR('[2,0,0]', 3, FLOAT32), COSINE)    AS cos_scaled,
       VECTOR_DISTANCE(VECTOR('[1,0,0]', 3, FLOAT32), VECTOR('[0,1,0]', 3, FLOAT32), EUCLIDEAN) AS euc_orth,
       VECTOR_DISTANCE(VECTOR('[1,0,0]', 3, FLOAT32), VECTOR('[2,0,0]', 3, FLOAT32), EUCLIDEAN) AS euc_scaled,
       VECTOR_DISTANCE(VECTOR('[1,0,0]', 3, FLOAT32), VECTOR('[2,0,0]', 3, FLOAT32), DOT)       AS dot_scaled
FROM   sysibm.sysdummy1;

-- 1b

SELECT a.query_id AS id_a, b.query_id AS id_b,
       VECTOR_DISTANCE(a.query_embedding, b.query_embedding, COSINE) AS dist
FROM   search_query a
JOIN   search_query b ON a.query_id < b.query_id
WHERE  a.query_id IN (1, 2, 102)
AND    b.query_id IN (1, 2, 102)
ORDER  BY dist;

-- 1c

SELECT VECTOR_DIMENSION_COUNT(TO_EMBEDDING('economical car for the daily commute'
                                           USING IDUGNA26.local_embedder)) AS dims,
       VECTOR_DISTANCE(TO_EMBEDDING('economical car for the daily commute'
                                    USING IDUGNA26.local_embedder),
                       q.query_embedding, COSINE) AS dist_to_phrase_1
FROM   search_query q
WHERE  q.query_id = 1;