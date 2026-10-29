-- =====================================================================
-- AutoNova lab 
--
-- ---------------------------------------------------------------------
-- convert the text into real VECTOR columns
-- (parents before children)
-- ---------------------------------------------------------------------
INSERT INTO listing
  (listing_id, vin, model_id, dealer_id, model_year, mileage, price, fuel_type,
   transmission, color, accident_free, owners, status, listed_date, description,
   desc_embedding)
SELECT listing_id, vin, model_id, dealer_id, model_year, mileage, price, fuel_type,
       transmission, color, accident_free, owners, status, listed_date, description,
       VECTOR(desc_emb_txt, 768, FLOAT32)
FROM   stg_listing;

INSERT INTO inspection_note
  (note_id, listing_id, inspected_on, category, severity, note_text, note_embedding)
SELECT note_id, listing_id, inspected_on, category, severity, note_text,
       VECTOR(note_emb_txt, 768, FLOAT32)
FROM   stg_inspection_note;

INSERT INTO owner_review
  (review_id, model_id, model_year, rating, mileage_at_review, review_text, review_embedding)
SELECT review_id, model_id, model_year, rating, mileage_at_review, review_text,
       VECTOR(review_emb_txt, 768, FLOAT32)
FROM   stg_owner_review;

INSERT INTO saved_search
  (saved_search_id, customer_id, max_price, max_mileage, min_year, search_text, search_embedding)
SELECT saved_search_id, customer_id, max_price, max_mileage, min_year, search_text,
       VECTOR(search_emb_txt, 768, FLOAT32)
FROM   stg_saved_search;

INSERT INTO kb_chunk
  (chunk_id, doc_title, topic, applies_to_state, chunk_text, chunk_embedding)
SELECT chunk_id, doc_title, topic, applies_to_state, chunk_text,
       VECTOR(chunk_emb_txt, 768, FLOAT32)
FROM   stg_kb_chunk;

INSERT INTO search_query (query_id, query_text, query_embedding)
SELECT query_id, query_text, VECTOR(query_emb_txt, 768, FLOAT32)
FROM   stg_search_query;

COMMIT;
