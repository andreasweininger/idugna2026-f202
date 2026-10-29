SET SCHEMA IDUGNA26;

SELECT 'listing' AS tab, COUNT(*) AS cnt FROM listing
UNION ALL SELECT 'inspection_note', COUNT(*) FROM inspection_note
UNION ALL SELECT 'owner_review',    COUNT(*) FROM owner_review
UNION ALL SELECT 'customer',        COUNT(*) FROM customer
UNION ALL SELECT 'kb_chunk',        COUNT(*) FROM kb_chunk
UNION ALL SELECT 'search_query',    COUNT(*) FROM search_query;

SELECT listing_id, model_year, color, price, status, SUBSTR(description, 1, 80) AS descr
FROM   listing
FETCH FIRST 5 ROWS ONLY;

SELECT VECTOR_DIMENSION_COUNT(desc_embedding) AS dims,
       SUBSTR(VECTOR_SERIALIZE(desc_embedding), 1, 60) AS first_values
FROM   listing
WHERE  listing_id = 1;