# HomeSchool Hub

Rails 8.1 app: Oak National Academy lessons in an iframe, Devise auth, per-learner school years, themes, progress + badges.

## Setup

```bash
bundle install
bin/rails db:migrate
bin/rails db:seed
bin/dev
```

Open http://localhost:3000 — sign up, choose school years (onboarding), then use the sidebar.

## Curriculum

- Year 7 programme links: `config/curriculum/oak_year7.yml`
- Refresh: `bin/rails curriculum:seed` or `bin/rails curriculum:resync` (wipes lessons)

## Deploy

See `docs/plan/DEPLOYMENT_ONCE.md` for ONCE.com / Docker notes. Repo root must contain `Gemfile` and `Dockerfile` (flat layout).

## Stack

- Ruby 4.x, SQLite (`storage/*.sqlite3`), Tailwind 4, Importmap + Turbo + Stimulus, Devise, Kamal config included.
