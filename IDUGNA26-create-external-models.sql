SET SCHEMA IDUGNA26;

DROP EXTERNAL IDUGNA26.local_embedder; 
CREATE EXTERNAL MODEL IDUGNA26.local_embedder
  PROVIDER OPENAI
  KEY 'ollama'
  ID 'nomic-embed-text'
  TYPE TEXT_EMBEDDING RETURNING VECTOR(768, FLOAT32)
  URL 'http://host.docker.internal:11434/v1/embeddings';

DROP EXTERNAL MODEL IDUGNA26.local_llm;
CREATE EXTERNAL MODEL IDUGNA26.local_llm
  PROVIDER OPENAI
  KEY 'ollam'
  ID 'llama3.2'
  TYPE TEXT_GENERATION RETURNING VARCHAR(5000)
  URL 'http://host.docker.internal:11434/v1/chat/completions';

SELECT modelschema, modelname, provider, modelid, modeltype, returntype
FROM   syscat.externalmodels
WHERE  modelschema = 'IDUGNA26';
