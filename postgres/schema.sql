-- Copied verbatim from benchmark/harness/schema.sql (Alula-Framework/benchmark)
-- — PLAN §4: "the issues/projects/users domain reused from the benchmark
-- suite," so the tutorial, the benchmark, and the eventual capstone all
-- teach against the same real schema, never three drifting approximations
-- of one. Kept as a literal copy rather than a package/submodule
-- dependency since it's SQL, not code with a version to pin; if the
-- benchmark schema changes, re-copy both this file and seed.sql together
-- and re-verify anything in content/ that shows their debugSQL output.
--
-- The literal shared schema for round 1. All three implementations run
-- against this exact schema — nobody's ORM/hand-rolled SQL gets to shape
-- the tables in its own favor.

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    owner_id UUID NOT NULL REFERENCES users(id),
    next_issue_number INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE issues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id),
    number INT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'open',
    priority TEXT NOT NULL DEFAULT 'normal',
    reporter_id UUID NOT NULL REFERENCES users(id),
    assignee_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (project_id, number)
);

CREATE INDEX issues_project_id_idx ON issues(project_id);
CREATE INDEX projects_owner_id_idx ON projects(owner_id);
