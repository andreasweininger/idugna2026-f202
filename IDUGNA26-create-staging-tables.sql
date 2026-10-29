-- =====================================================================
-- AutoNova lab 
--
-- Embeddings are pre-computed with
--   TO_EMBEDDING(text USING IDUGNA26.local_embedder)
-- and shipped as text ("[0.0123, -0.0456, ...]" with 768 values).
-- The staging tables hold the vector as CLOB text, so that IMPORT / LOAD
-- works on them. The target tables get the real VECTOR via VECTOR().
--
-- IMPORTANT: load all data BEFORE  building vector index
--
-- Order of the data files = dependency order of the tables:
--   dealer, car_model, customer             (no vectors, load directly)
--   listing, inspection_note, owner_review,
--   saved_search, favorite, kb_chunk, search_query
-- =====================================================================

SET SCHEMA IDUGNA26;

-- ---------------------------------------------------------------------
-- Staging tables (same columns as the targets, vector as CLOB text)
-- ---------------------------------------------------------------------
CREATE TABLE stg_listing (
  listing_id     INT,
  vin            CHAR(17),
  model_id       INT,
  dealer_id      INT,
  model_year     SMALLINT,
  mileage        INT,
  price          DECIMAL(9,2),
  fuel_type      VARCHAR(12),
  transmission   VARCHAR(10),
  color          VARCHAR(20),
  accident_free  CHAR(1),
  owners         SMALLINT,
  status         VARCHAR(10),
  listed_date    DATE,
  description    VARCHAR(2000),
  desc_emb_txt   CLOB(100K)
) ORGANIZE BY ROW;

CREATE TABLE stg_listing_incoming (
  listing_id     INT,
  vin            CHAR(17),
  model_id       INT,
  dealer_id      INT,
  model_year     SMALLINT,
  mileage        INT,
  price          DECIMAL(9,2),
  fuel_type      VARCHAR(12),
  transmission   VARCHAR(10),
  color          VARCHAR(20),
  accident_free  CHAR(1),
  owners         SMALLINT,
  status         VARCHAR(10),
  listed_date    DATE,
  description    VARCHAR(2000),
  desc_emb_txt   CLOB(100K)
) ORGANIZE BY ROW;

CREATE TABLE stg_inspection_note (
  note_id        INT,
  listing_id     INT,
  inspected_on   DATE,
  category       VARCHAR(20),
  severity       SMALLINT,
  note_text      VARCHAR(1000),
  note_emb_txt   CLOB(100K)
) ORGANIZE BY ROW;

CREATE TABLE stg_owner_review (
  review_id         INT,
  model_id          INT,
  model_year        SMALLINT,
  rating            SMALLINT,
  mileage_at_review INT,
  review_text       VARCHAR(2000),
  review_emb_txt    CLOB(100K)
) ORGANIZE BY ROW;

CREATE TABLE stg_saved_search (
  saved_search_id INT,
  customer_id     INT,
  max_price       DECIMAL(9,2),
  max_mileage     INT,
  min_year        SMALLINT,
  search_text     VARCHAR(500),
  search_emb_txt  CLOB(100K)
) ORGANIZE BY ROW;

CREATE TABLE stg_kb_chunk (
  chunk_id         INT,
  doc_title        VARCHAR(120),
  topic            VARCHAR(20),
  applies_to_state CHAR(2),
  chunk_text       VARCHAR(2000),
  chunk_emb_txt    CLOB(100K)
) ORGANIZE BY ROW;

CREATE TABLE stg_search_query (
  query_id       INT,
  query_text     VARCHAR(500),
  query_emb_txt  CLOB(100K)
) ORGANIZE BY ROW;

