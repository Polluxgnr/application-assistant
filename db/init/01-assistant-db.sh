#!/bin/sh
# Runs once, on the first start of the Postgres volume.
# n8n keeps its own data in $POSTGRES_DB; the bot's data lives in a separate project database.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -c "CREATE DATABASE \"${ASSISTANT_DB:-assistant}\""

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${ASSISTANT_DB:-assistant}" <<'SQL'
-- One row per user: the uploaded CV, as text and as parsed JSON. /cv again replaces it.
CREATE TABLE profiles (
  user_id     text PRIMARY KEY,
  full_name   text,
  base_cv     text  NOT NULL,
  cv_profile  jsonb NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Long-term memory: what the user confirmed (skill, experience) or denied (gap).
-- The unique key makes saving the same fact twice a no-op (idempotent).
CREATE TABLE facts (
  id          bigserial PRIMARY KEY,
  user_id     text NOT NULL,
  kind        text NOT NULL CHECK (kind IN ('skill', 'experience', 'gap', 'answer')),
  value       text NOT NULL,
  source      text NOT NULL DEFAULT 'answer',
  value_hash  text GENERATED ALWAYS AS (md5(lower(value))) STORED,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, kind, value_hash)
);

-- Short-term memory: the job in progress, one row per user.
CREATE TABLE sessions (
  user_id       text PRIMARY KEY,
  state         text NOT NULL CHECK (state IN ('waiting', 'ready', 'done')),
  job_url       text,
  job_json      jsonb,
  job_text      text,
  missing_json  jsonb,
  question      text,
  match_score   integer,
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Execution id -> who sent the command, so the error workflow can warn the right user.
CREATE TABLE runs (
  execution_id  text PRIMARY KEY,
  user_id       text,
  app_id        text,
  token         text,
  command       text,
  created_at    timestamptz NOT NULL DEFAULT now()
);
SQL
