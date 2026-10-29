SET SCHEMA IDUGNA26;

-- 8

WITH q AS (
  SELECT TO_EMBEDDING('Can I return the car if I bought it online?'
                      USING IDUGNA26.local_embedder) AS qe
  FROM   sysibm.sysdummy1
),
ctx AS (
  SELECT LISTAGG(chunk_text, ' ') WITHIN GROUP (ORDER BY dist) AS context
  FROM (
    SELECT k.chunk_text,
           VECTOR_DISTANCE(k.chunk_embedding, q.qe, COSINE) AS dist
    FROM   kb_chunk k, q
    WHERE  k.applies_to_state IS NULL OR k.applies_to_state = 'TX'
    ORDER  BY dist
    FETCH FIRST 3 ROWS ONLY
  ) t
)
SELECT TEXT_GENERATION(
         'Answer using only the context. If the answer is not in the context, say you do not know. '
         || 'Context: ' || context
         || ' Question: Can I return the car if I bought it online?'
         USING IDUGNA26.local_llm) AS answer
FROM   ctx;