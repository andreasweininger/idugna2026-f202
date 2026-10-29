# AutoNova: Vectors Meet Relational Data in Db2 12.1.5

**Hands-on lab, IDUG NA**

You work for **AutoNova**, a fictional used-car marketplace. Customers search for cars in free text ("cheap to run commuter car"), want filters that always hold (budget, status, distance) and expect "similar" results instead of only exact matches. In this lab you build those features with plain SQL in Db2.

> All makes, models, dealers and people in the data are fictional. The "defects" in the data (for example a transmission shudder) say nothing about real cars.

## Before you start

The preparation steps as described in the presentation must have been executed first.
- Two external models are registered in schema `IDUGNA26` and you have `USAGE` on both:
  - `IDUGNA26.local_embedder`: text to `VECTOR(768, FLOAT32)`
  - `IDUGNA26.local_llm`: text generation (used in Exercise 8)
- Every model call is an HTTP request. Calling `TO_EMBEDDING` on thousands of rows is slow, so most tables already contain embeddings and the table `search_query` holds 10 pre-embedded search phrases.
- The exercises build on each other. Do them in order. Exercises marked **(optional)** can be skipped if you run short of time.

## The data

| Table | What it holds | Vector column |
|---|---|---|
| `listing` | cars for sale: model year, mileage, price, fuel, color, status, free-text description | `desc_embedding` (description) |
| `car_model`, `dealer`, `color_ref` | reference data (body type, location, RGB values of colors) | none |
| `inspection_note` | inspector comments per listing | `note_embedding` |
| `owner_review` | reviews per model and model year | `review_embedding` |
| `customer`, `favorite`, `saved_search` | buyers, what they saved, and their saved searches | `search_embedding` |
| `kb_chunk` | AutoNova policy text for the chatbot (RAG) | `chunk_embedding` |
| `search_query` | 10 pre-embedded search phrases (ids 1-8, 102, 110) | `query_embedding` |
| `car_request`, `feat_weight` | input and weights for the multi-column search (Exercise 5) | none |

Views `v_car_scaled` and `v_car_feat` turn several relational columns into one vector. You use them in Exercise 5.

Distance convention: with `COSINE`, **smaller means more similar**. `0` is identical, values near `1` are unrelated.

---

## Exercise 0: Orientation (5 min)

**Goal:** know what is in your schema.

1. Count the rows of `listing`, `inspection_note`, `owner_review`, `customer`, `kb_chunk` and `search_query`.
2. Show five listings with `listing_id`, `model_year`, `color`, `price`, `status` and the first 80 characters of `description`.
3. For one listing show `VECTOR_DIMENSION_COUNT(desc_embedding)` and the first 60 characters of `VECTOR_SERIALIZE(desc_embedding)`.

*Question:* which columns of `listing` can you filter with ordinary SQL, and which one holds the "meaning" of the description?

---

## Exercise 1: Vector basics (10 min)

**Goal:** compute distances by hand and see what the metrics do.

**1a.** Create three tiny 3-dimensional vectors with `VECTOR('[1,0,0]', 3, FLOAT32)` and so on. Compute `VECTOR_DISTANCE` between `[1,0,0]` and `[0,1,0]`, and between `[1,0,0]` and `[2,0,0]`, with the metrics `COSINE`, `EUCLIDEAN` and `DOT`.

*Question:* why is the `COSINE` distance of `[1,0,0]` and `[2,0,0]` zero but the `EUCLIDEAN` distance is not?

**1b.** Compare two stored search phrases from `search_query`:

- phrase 1: "cheap to run commuter car for a long daily drive"
- phrase 2: "reliable family SUV with room for three car seats and a dog"
- phrase 102: "quiet and comfortable on long road trips"

Cross join the table with itself for ids 1, 2 and 102 and list the cosine distance of every pair.

**1c.** Embed a phrase of your own with `TO_EMBEDDING(... USING IDUGNA26.local_embedder)` and compare it with phrase 1. Check `VECTOR_DIMENSION_COUNT` of the result.

*Hint:* `TO_EMBEDDING` is called once per statement here. Do not call it for every row of a big table.

---

## Exercise 2: Semantic search versus keyword search (10 min)

**Goal:** see why vector search finds what `LIKE` misses.

**2a.** Find listings whose description contains "fuel efficient" or "good gas mileage" with `LIKE`. How many are there?

**2b.** Rank all listings by cosine distance to phrase 1 ("cheap to run commuter car for a long daily drive") and show the top 10 with their description.

**2c.** Compare the two result lists. Which top-10 listings from 2b would `LIKE` never have found? Which words in their descriptions mean the same thing?

*Starter:*

```sql
SELECT l.listing_id, l.fuel_type, l.price,
       VECTOR_DISTANCE(l.desc_embedding, q.query_embedding, COSINE) AS dist,
       SUBSTR(l.description, 1, 100) AS descr
FROM   listing l, search_query q
WHERE  q.query_id = 1
-- TODO: order and limit
;
```

---

## Exercise 3: Hybrid search, SQL filters plus similarity (15 min)

**Goal:** combine hard conditions (SQL) with soft conditions (vector similarity).

Customer **77** wants phrase 1 ("cheap to run commuter car for a long daily drive").

**3a.** Add the hard conditions: `status = 'AVAILABLE'`, `price` not above the customer's `budget_max`.

*Question:* which listings from 2b disappeared? (Some are sold and some are too expensive. They are good semantic matches that SQL correctly removes.)

**3b.** Add a similarity cut-off: return only listings with `dist < 0.35`. Look at the distances of your result and move the cut-off up and down.

*Question:* what is the trade-off of a low cut-off versus a high one?

**3c.** Add the distance between the customer's home (`home_lat`, `home_lon`) and the dealer (`latitude`, `longitude`). Use this approximation in miles:

```
69.0 * SQRT( POWER(d.latitude - c.home_lat, 2)
           + POWER(COS(RADIANS(c.home_lat)) * (d.longitude - c.home_lon), 2) )
```

Keep only listings within 100 miles.

**3d.** Trust but verify. Descriptions are free text, but `accident_free` is the authoritative flag from the history report. Search for phrase 4 ("clean one-owner car, never been in an accident") and list the top 30 where `accident_free = 'N'`.

*Question:* what does this tell you about using the text of a description as a fact?

---

## Exercise 4: Vectors across several tables (10 min) (optional)

**Goal:** join vector search results to relational data and aggregate.

**4a. Which dealers have a rust problem?** Search `inspection_note` for phrase 5 ("rust or corrosion on the underbody or frame"). Notes about rust are worded in five different ways. Keep notes with `dist < 0.45`, join them to `listing` and `dealer`, and count notes per dealer. Show the top 5 dealers.

**4b. Which cars to avoid?** Search `owner_review` for phrase 6 ("transmission slipping, shuddering or jerking between gears"). Count the matching reviews (`dist < 0.45`) per `make`, `model` and `model_year`. Then list the `AVAILABLE` listings of those model-year combinations with at least 5 matching reviews.

**4c. Duplicates across dealers.** Some cars are listed twice at different dealers with reworded text. Find pairs of listings with the same `model_id`, the same `model_year`, different dealers, mileage within 2 %, and a description distance below 0.1. Limit the join so it does not compare all 5,000 x 5,000 rows.

---

## Exercise 5: Multi-column similarity (30 min)

**Goal:** ask for "blue, 2020" and also get "light blue" and 2019 or 2021, using more than two columns, without any text model.

A buyer asks for: **blue**, **model year 2020**, **hybrid SUV**, **automatic**, about **45,000 miles**, about **$24,000**, **one owner**. A normal `WHERE` clause returns only exact matches. We want a ranking by overall closeness.

**The idea:** turn each car into a point in a space. Each column becomes numbers:

| Column | Encoded as |
|---|---|
| color | 3 numbers: R, G, B from `color_ref` (so light blue is close to blue) |
| model year | one number on a scale where 1 year = 0.1 |
| mileage, price | one number each (10k miles = 0.1, $3,000 = 0.1) |
| fuel type | degree of electrification: gasoline 0, hybrid 0.5, PHEV 0.75, EV 1 |
| transmission, owners | one number each |
| body type | one-hot: 7 numbers, 1 for the body type, 0 for the rest |

That makes **16 dimensions**. Every number is multiplied by a weight from `feat_weight` (0 means "don't care"). The views `v_car_scaled` and `v_car_feat` do all of this for listings (`src = 'L'`) and for requests (`src = 'R'`).

**5a. Create the request.** Insert the request above into `car_request` with `request_id = 1`.

**5b. Look at the vectors.** Select the `feat` vector of request 1 and of three listings from `v_car_feat`. Check that `VECTOR_DIMENSION_COUNT` is 16.

**5c. Search.** Rank all `AVAILABLE` listings by `VECTOR_DISTANCE(listing_feat, request_feat, EUCLIDEAN)` and show the top 25 with `color`, `model_year`, `mileage`, `price` and `fuel_type`.

*Expected:* the exact blue 2020 hybrid SUVs come first. Then come blue 2019 and 2021, light blue and teal. Trucks and red cars come much later.

**5d. Turn the knobs.** Change the weights in `feat_weight` and rerun 5c:

1. Color is the most important thing: `w_color = 3`.
2. The year is exact: `w_year = 4`.
3. Color does not matter: `w_color = 0`.

Restore the default weights afterwards (1.00, 1.00, 0.50, 0.50, 0.50, 0.25, 0.25, 1.00).

*Question:* which weight made navy cars move up or down?

**5e. Add a column.** Add `accident_free` as a 17th dimension. You must change three things: the weights table, the view `v_car_scaled` (both branches of the `UNION ALL`) and the view `v_car_feat` (the new element and the dimension of `VECTOR(...)`). A request has no accident flag, so use a constant "wants accident-free" for the requests.

**5f. The text alternative.** Instead of numbers, serialize the columns into a sentence, embed the sentence and let the language model decide what "similar" means.

1. For listings 1 to 100 fill `attr_embedding` with `TO_EMBEDDING('color: ' || color || '; model year: ' || RTRIM(CHAR(model_year)) || '; fuel: ' || fuel_type || '; transmission: ' || transmission USING IDUGNA26.local_embedder)`. (100 HTTP calls, so it takes a moment.)
2. Search with the pre-embedded phrase 110 ("color: light blue; model year: 2020; fuel: HYBRID; transmission: AUTOMATIC").
3. Compare the ranking with 5c.

*Question:* which approach respects "2019 is closer to 2020 than 2012"? Which one needs no numeric scaling work? Which one can you tune?

**5g. Fuse both signals.** The buyer also types a free-text wish, "quiet and comfortable on long road trips" (phrase 102). Combine the 5c feature ranking and the description ranking with **reciprocal rank fusion**: `score = 1/(60 + rank_features) + 1/(60 + rank_description)`. Show the top 10.

---

## Exercise 6: Recommendations (10 min) (optional)

**6a. More like this.** Take listing 1. Find the 10 most similar `AVAILABLE` listings by description, excluding listing 1 itself.

**6b. For you.** Customer 77 has 10 favorites.

1. Find `AVAILABLE` listings the customer has not saved, with `price <= budget_max`.
2. Score each by the **average cosine distance to all favorites** of the customer. Show the top 10.

**6c. Reverse matching.** A new listing (id 9001) arrives. Insert it using the pattern in `04_staging_and_load.sql`, Step 3c. Which saved searches should be notified? A saved search matches if its text is close (`dist < 0.40`) **and** `max_price >= price`, `max_mileage >= mileage`, `min_year <= model_year`. Show customer, search text and distance.

---

## Exercise 7: Vector index (10 min)

**Goal:** see the difference between exact and index-supported search.

Run this on your own table: it is an offline operation and takes a table lock, so go in the order the instructor gives.

1. Run the query from 2b with `EXPLAIN` and note the plan and its cost. (Instructor shows how to read the plan.)
2. Time the query. Do it three times.
3. Run `05_vector_index.sql`.
4. Run the `EXPLAIN` again. Is the vector index used? Time the query again.
5. Insert the remaining incoming listings (`9002` to `9020`) from `stg_listing`. They are searchable right away. Find them with a query for phrase 1.
6. Add `status = 'AVAILABLE'` and `price <= 20000` to the query. Count the rows you get back.

*Questions:*

- Why must the `ORDER BY` use the same metric as the index (`COSINE`)?
- With an approximate index and a filter, can a query return fewer than the requested number of rows? Why?
- Which operations does Db2 block on a table with a vector index? (Check the header of `05_vector_index.sql`.)

---

## Exercise 8: Retrieval-augmented answer with `TEXT_GENERATION` (10 min) (optional)

**Goal:** a policy chatbot in one SQL statement.

A customer from **TX** asks: "Can I return the car if I bought it online?"

1. Embed the question with `TO_EMBEDDING`.
2. Retrieve the 3 closest chunks from `kb_chunk`. Keep chunks with `applies_to_state IS NULL` or `applies_to_state = 'TX'`.
3. Concatenate the chunk texts with `LISTAGG` into one context string.
4. Call `TEXT_GENERATION(prompt USING IDUGNA26.local_llm)` with a prompt like: "Answer using only the context. If the answer is not in the context, say you do not know. Context: ... Question: ..."
5. Ask a question the knowledge base cannot answer ("Do you sell motorcycles?") and see what the model does.

*Question:* what does the `applies_to_state` filter do for the quality of the answer?

---

## Wrap-up

| You learned | Where |
|---|---|
| `VECTOR`, `VECTOR_DISTANCE` and the metrics | 1 |
| Semantic search beats keywords | 2 |
| SQL filters plus similarity (hybrid) | 3 |
| Vector search across tables with joins and aggregates | 4 |
| Similarity over several relational columns | 5 |
| Recommendations and reverse matching | 6 |
| Vector index: speed and its limits | 7 |
| Retrieval-augmented generation | 8 |

Solutions are in `solutions.md` (instructor copy).
