# HomeSchool Hub

Rails 8.1 app: Oak National Academy lessons rendered in-app (Open Government Licence content), Devise auth, parent/learner roles, per-learner years and subjects, themes, progress, badges, and a simple insights view for families.

## Setup

```bash
bundle install
bin/rails db:migrate
bin/rails db:seed
bin/dev
```

Open http://localhost:3000 — the landing page explains how the hub uses Oak’s Open API. After sign-up, **parents** complete setup (school years, then subject preferences). **Learners** can be invited by email from the app; they sign up with the same address and are linked to the parent account. Parents can open **Insights** for completion and study-time summaries.

## Curriculum

- Starter links: `config/curriculum/oak_year7.yml`
- **Oak Open API** (free key from [Oak’s API docs](https://open-api.thenational.academy/docs)): set `OAK_API_TOKEN` in your environment (or set `OAK_API_AUTH_HEADER` to the full `Authorization` value if Oak gives a non-Bearer format). Subjects and years are listed in `config/oak_curriculum.yml`.
- Import lessons: `bin/rails curriculum:oak_sync` (or `curriculum:seed` / `curriculum:resync`, which call the importer when a token is set).
- Optional: `OAK_IMPORT_LIMIT=5` caps lessons per subject while testing the sync.

## Deploy

See `docs/plan/DEPLOYMENT_ONCE.md` for ONCE.com / Docker notes. Repo root must contain `Gemfile` and `Dockerfile` (flat layout).

## Stack

- Ruby 4.x, SQLite (`storage/*.sqlite3`), Tailwind 4, Importmap + Turbo + Stimulus, Devise, Kamal config included.
