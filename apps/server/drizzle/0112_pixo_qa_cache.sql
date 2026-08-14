-- Cache of questions pixo has already answered from the docs, so a similar
-- question can be answered instantly without re-fetching docs or calling the
-- model again. question_norm is the lowercased/punctuation-stripped question
-- used for cheap exact + token-overlap matching.
--
-- Run against the orchard/CNPG database. Safe to run more than once.

CREATE TABLE IF NOT EXISTS public.pixo_qa_cache (
  id            bigserial   PRIMARY KEY,
  question      text        NOT NULL,
  question_norm text        NOT NULL,
  answer        text        NOT NULL,
  source        text        NOT NULL DEFAULT 'docs',
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS pixo_qa_cache_norm_idx
  ON public.pixo_qa_cache (question_norm);
