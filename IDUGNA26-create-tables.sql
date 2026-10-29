SET SCHEMA IDUGNA26;

-- =====================================================================
-- AutoNova lab 
--
--   db2 connect to <dbname>
--   db2 -tvf 01_tables.sql
--
-- Tables are created in dependency order (parents before children).
-- All tables are row-organized and non-partitioned (required for vector indexes).
-- Every embedding column that may be indexed is NOT NULL (required so the
-- optimizer can choose the vector index).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Level 0: reference tables without foreign keys
-- ---------------------------------------------------------------------

-- Color reference: RGB values used by the multi-column similarity exercise (Ex. 5)
CREATE TABLE color_ref (
  color_name  VARCHAR(20) NOT NULL,
  r           SMALLINT    NOT NULL,
  g           SMALLINT    NOT NULL,
  b           SMALLINT    NOT NULL,
  CONSTRAINT pk_color_ref PRIMARY KEY (color_name),
  CONSTRAINT ck_color_rgb CHECK (r BETWEEN 0 AND 255
                             AND g BETWEEN 0 AND 255
                             AND b BETWEEN 0 AND 255)
) ORGANIZE BY ROW;

CREATE TABLE dealer (
  dealer_id    INT           NOT NULL,
  dealer_name  VARCHAR(80)   NOT NULL,
  city         VARCHAR(60)   NOT NULL,
  state        CHAR(2)       NOT NULL,
  latitude     DECIMAL(9,6)  NOT NULL,
  longitude    DECIMAL(9,6)  NOT NULL,
  rating       DECIMAL(3,2),
  CONSTRAINT pk_dealer PRIMARY KEY (dealer_id)
) ORGANIZE BY ROW;

CREATE TABLE car_model (
  model_id      INT           NOT NULL,
  make          VARCHAR(30)   NOT NULL,
  model         VARCHAR(40)   NOT NULL,
  body_type     VARCHAR(12)   NOT NULL,
  seats         SMALLINT      NOT NULL,
  original_msrp DECIMAL(9,2),
  CONSTRAINT pk_car_model PRIMARY KEY (model_id),
  CONSTRAINT ck_body_type CHECK (body_type IN
    ('SEDAN','SUV','TRUCK','HATCHBACK','WAGON','MINIVAN','COUPE'))
) ORGANIZE BY ROW;

CREATE TABLE customer (
  customer_id    INT           NOT NULL,
  customer_name  VARCHAR(80)   NOT NULL,
  state          CHAR(2)       NOT NULL,
  home_lat       DECIMAL(9,6),
  home_lon       DECIMAL(9,6),
  budget_max     DECIMAL(9,2),
  CONSTRAINT pk_customer PRIMARY KEY (customer_id)
) ORGANIZE BY ROW;

-- Knowledge base chunks for RAG (Ex. 8). No foreign keys.
CREATE TABLE kb_chunk (
  chunk_id         INT            NOT NULL,
  doc_title        VARCHAR(120)   NOT NULL,
  topic            VARCHAR(20)    NOT NULL,        -- WARRANTY, RETURNS, FINANCING, ...
  applies_to_state CHAR(2),                         -- NULL = all states
  chunk_text       VARCHAR(2000)  NOT NULL,
  chunk_embedding  VECTOR(768, FLOAT32) NOT NULL,
  CONSTRAINT pk_kb_chunk PRIMARY KEY (chunk_id)
) ORGANIZE BY ROW;

-- Pre-embedded search phrases (embed once, reuse in many queries)
CREATE TABLE search_query (
  query_id         INT            NOT NULL,
  query_text       VARCHAR(500)   NOT NULL,
  query_embedding  VECTOR(768, FLOAT32) NOT NULL,
  CONSTRAINT pk_search_query PRIMARY KEY (query_id)
) ORGANIZE BY ROW;

-- Weights for the multi-column feature vector (Ex. 5). Exactly one row.
-- A weight of 0 means "don't care" for that group of columns.
CREATE TABLE feat_weight (
  w_color    DECIMAL(4,2) NOT NULL,
  w_year     DECIMAL(4,2) NOT NULL,
  w_mileage  DECIMAL(4,2) NOT NULL,
  w_price    DECIMAL(4,2) NOT NULL,
  w_fuel     DECIMAL(4,2) NOT NULL,
  w_trans    DECIMAL(4,2) NOT NULL,
  w_owners   DECIMAL(4,2) NOT NULL,
  w_body     DECIMAL(4,2) NOT NULL
) ORGANIZE BY ROW;

-- ---------------------------------------------------------------------
-- Level 1: tables that reference level 0
-- ---------------------------------------------------------------------

CREATE TABLE listing (
  listing_id      INT            NOT NULL,
  vin             CHAR(17)       NOT NULL,
  model_id        INT            NOT NULL,
  dealer_id       INT            NOT NULL,
  model_year      SMALLINT       NOT NULL,
  mileage         INT            NOT NULL,
  price           DECIMAL(9,2)   NOT NULL,
  fuel_type       VARCHAR(12)    NOT NULL,         -- GASOLINE, DIESEL, HYBRID, PHEV, EV
  transmission    VARCHAR(10)    NOT NULL,         -- AUTOMATIC, MANUAL
  color           VARCHAR(20)    NOT NULL,
  accident_free   CHAR(1)        NOT NULL,         -- authoritative flag from the history report
  owners          SMALLINT       NOT NULL,
  status          VARCHAR(10)    NOT NULL,         -- AVAILABLE, PENDING, SOLD
  listed_date     DATE           NOT NULL,
  description     VARCHAR(2000)  NOT NULL,
  desc_embedding  VECTOR(768, FLOAT32) NOT NULL,   -- embedding of the description text
  attr_embedding  VECTOR(768, FLOAT32),            -- embedding of serialized columns (Ex. 5e)
  CONSTRAINT pk_listing        PRIMARY KEY (listing_id),
  CONSTRAINT uq_listing_vin    UNIQUE (vin),
  CONSTRAINT fk_listing_model  FOREIGN KEY (model_id)  REFERENCES car_model (model_id),
  CONSTRAINT fk_listing_dealer FOREIGN KEY (dealer_id) REFERENCES dealer (dealer_id),
  CONSTRAINT fk_listing_color  FOREIGN KEY (color)     REFERENCES color_ref (color_name),
  CONSTRAINT ck_listing_acc    CHECK (accident_free IN ('Y','N')),
  CONSTRAINT ck_listing_fuel   CHECK (fuel_type IN ('GASOLINE','DIESEL','HYBRID','PHEV','EV')),
  CONSTRAINT ck_listing_trans  CHECK (transmission IN ('AUTOMATIC','MANUAL')),
  CONSTRAINT ck_listing_status CHECK (status IN ('AVAILABLE','PENDING','SOLD')),
  CONSTRAINT ck_listing_nums   CHECK (mileage >= 0 AND price >= 0 AND owners >= 0)
) ORGANIZE BY ROW;

CREATE TABLE owner_review (
  review_id         INT            NOT NULL,
  model_id          INT            NOT NULL,
  model_year        SMALLINT       NOT NULL,
  rating            SMALLINT       NOT NULL,
  mileage_at_review INT,
  review_text       VARCHAR(2000)  NOT NULL,
  review_embedding  VECTOR(768, FLOAT32) NOT NULL,
  CONSTRAINT pk_owner_review  PRIMARY KEY (review_id),
  CONSTRAINT fk_review_model  FOREIGN KEY (model_id) REFERENCES car_model (model_id),
  CONSTRAINT ck_review_rating CHECK (rating BETWEEN 1 AND 5)
) ORGANIZE BY ROW;

CREATE TABLE saved_search (
  saved_search_id   INT            NOT NULL,
  customer_id       INT            NOT NULL,
  max_price         DECIMAL(9,2),
  max_mileage       INT,
  min_year          SMALLINT,
  search_text       VARCHAR(500)   NOT NULL,
  search_embedding  VECTOR(768, FLOAT32) NOT NULL,
  CONSTRAINT pk_saved_search  PRIMARY KEY (saved_search_id),
  CONSTRAINT fk_saved_cust    FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
) ORGANIZE BY ROW;

-- Input of the multi-column similarity search (Ex. 5): "what the buyer asks for"
CREATE TABLE car_request (
  request_id    INT           NOT NULL,
  color         VARCHAR(20)   NOT NULL,
  model_year    SMALLINT      NOT NULL,
  mileage       INT           NOT NULL,
  price         DECIMAL(9,2)  NOT NULL,
  fuel_type     VARCHAR(12)   NOT NULL,
  transmission  VARCHAR(10)   NOT NULL,
  owners        SMALLINT      NOT NULL,
  body_type     VARCHAR(12)   NOT NULL,
  CONSTRAINT pk_car_request  PRIMARY KEY (request_id),
  CONSTRAINT fk_request_color FOREIGN KEY (color) REFERENCES color_ref (color_name),
  CONSTRAINT ck_request_body CHECK (body_type IN
    ('SEDAN','SUV','TRUCK','HATCHBACK','WAGON','MINIVAN','COUPE'))
) ORGANIZE BY ROW;

-- ---------------------------------------------------------------------
-- Level 2: tables that reference listing
-- ---------------------------------------------------------------------

CREATE TABLE inspection_note (
  note_id          INT            NOT NULL,
  listing_id       INT            NOT NULL,
  inspected_on     DATE           NOT NULL,
  category         VARCHAR(20)    NOT NULL,        -- BODY, ENGINE, TRANSMISSION, ...
  severity         SMALLINT       NOT NULL,
  note_text        VARCHAR(1000)  NOT NULL,
  note_embedding   VECTOR(768, FLOAT32) NOT NULL,
  CONSTRAINT pk_inspection_note PRIMARY KEY (note_id),
  CONSTRAINT fk_note_listing    FOREIGN KEY (listing_id) REFERENCES listing (listing_id),
  CONSTRAINT ck_note_severity   CHECK (severity BETWEEN 1 AND 5)
) ORGANIZE BY ROW;

CREATE TABLE favorite (
  customer_id  INT        NOT NULL,
  listing_id   INT        NOT NULL,
  fav_ts       TIMESTAMP  NOT NULL DEFAULT CURRENT TIMESTAMP,
  CONSTRAINT pk_favorite       PRIMARY KEY (customer_id, listing_id),
  CONSTRAINT fk_fav_customer   FOREIGN KEY (customer_id) REFERENCES customer (customer_id),
  CONSTRAINT fk_fav_listing    FOREIGN KEY (listing_id)  REFERENCES listing (listing_id)
) ORGANIZE BY ROW;

-- ---------------------------------------------------------------------
-- Regular (non-vector) indexes. 
-- Create the vector index last
-- (05_vector_index.sql), after all bulk loading is done.
-- ---------------------------------------------------------------------
CREATE INDEX ix_listing_status_price ON listing (status, price);
CREATE INDEX ix_listing_model_year   ON listing (model_id, model_year);
CREATE INDEX ix_listing_dealer       ON listing (dealer_id);
CREATE INDEX ix_note_listing         ON inspection_note (listing_id);
CREATE INDEX ix_review_model_year    ON owner_review (model_id, model_year);
CREATE INDEX ix_favorite_listing     ON favorite (listing_id);
CREATE INDEX ix_saved_customer       ON saved_search (customer_id);
CREATE INDEX ix_kb_topic             ON kb_chunk (topic);


