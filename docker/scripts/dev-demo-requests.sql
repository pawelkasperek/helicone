-- Local-only demo seed (ClickHouse part): 600 synthetic requests spread over
-- the last 30 days for the demo organization created by dev-demo-seed.sql.
--
-- The runner deletes this org's previous rows first, so re-running replaces
-- them instead of duplicating (see dev-demo-seed.sh).
--
-- Notes on the values:
--   * `cost` is stored in nanodollars: jawn divides by COST_PRECISION_MULTIPLIER
--     (1_000_000_000) when reading (packages/cost/costCalc.ts).
--   * `storage_location = 'clickhouse'` makes jawn parse request_body /
--     response_body straight from ClickHouse instead of signing S3 URLs
--     (lib/stores/request/request.ts, mapLLMCalls), so no MinIO objects needed.
--   * `status` alternates a small share of 400/500 so the error panels have data.
INSERT INTO request_response_rmt
(
  response_id, response_created_at, latency, status, completion_tokens, prompt_tokens,
  model, provider, request_id, request_created_at, user_id, organization_id,
  cache_reference_id, properties, scores, assets, threat, time_to_first_token,
  country_code, target_url, cost, prompt_id, storage_location, request_body, response_body, updated_at
)
SELECT
  generateUUIDv4()                                                 AS response_id,
  t.ts                                                             AS response_created_at,
  toInt64(rand() % 2200 + 150)                                     AS latency,
  toInt64(if(number % 29 = 0, 500, if(number % 13 = 0, 400, 200))) AS status,
  toInt64(rand() % 300 + 15)                                       AS completion_tokens,
  toInt64(rand() % 700 + 40)                                       AS prompt_tokens,
  ['gpt-4o-mini', 'gpt-4o', 'claude-3-5-sonnet-20241022', 'gemini-1.5-flash', 'gpt-4o-mini'][(number % 5) + 1] AS model,
  ['openai', 'openai', 'anthropic', 'google', 'openai'][(number % 5) + 1]                                     AS provider,
  generateUUIDv4()                                                 AS request_id,
  t.ts                                                             AS request_created_at,
  concat('demo-user-', toString(number % 18 + 1))                  AS user_id,
  toUUID('dddddddd-1111-4111-8111-111111111111')                   AS organization_id,
  generateUUIDv4()                                                 AS cache_reference_id,
  map(
    'Helicone-Property-Environment', 'demo',
    'Helicone-Property-Feature', ['chatbot', 'summarize', 'extract', 'translate'][(number % 4) + 1]
  )                                                                AS properties,
  map()                                                            AS scores,
  emptyArrayString()                                               AS assets,
  false                                                            AS threat,
  toInt64(rand() % 400 + 40)                                       AS time_to_first_token,
  ['US', 'GB', 'DE', 'IN', 'JP', 'BR'][(number % 6) + 1]           AS country_code,
  'https://api.openai.com/v1/chat/completions'                     AS target_url,
  toUInt64(rand() % 50000000 + 1000000)                            AS cost,
  ['demo-chatbot', 'demo-summarize'][(number % 2) + 1]             AS prompt_id,
  'clickhouse'                                                     AS storage_location,
  '{"model":"gpt-4o-mini","messages":[{"role":"system","content":"You are a helpful assistant."},{"role":"user","content":"Summarize this support ticket in one sentence."}],"max_tokens":256}' AS request_body,
  '{"id":"chatcmpl-demo","object":"chat.completion","model":"gpt-4o-mini","choices":[{"index":0,"message":{"role":"assistant","content":"This is seeded demo data for local development."},"finish_reason":"stop"}],"usage":{"prompt_tokens":120,"completion_tokens":48,"total_tokens":168}}' AS response_body,
  now64(3)                                                         AS updated_at
FROM (
  SELECT number, now64(3) - toIntervalSecond(number * 4300) AS ts
  FROM numbers(600)
) AS t;
