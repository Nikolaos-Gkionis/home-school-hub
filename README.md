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

- Starter rows: `config/curriculum/oak_year7.yml` (optional links; rows whose URLs match `/pupils/lessons/{slug}` are upgraded to `oak_hub` on seed).
- **Oak Open API** ([overview](https://open-api.thenational.academy/docs/about-oaks-api/api-overview), [terms](https://open-api.thenational.academy/docs/about-oaks-api/terms-and-conditions)): set `OAK_API_TOKEN` (or `OAK_API_AUTH_HEADER` for a full non-Bearer `Authorization` value). Subjects and years for sync live in `config/oak_curriculum.yml`.
- Import + hydrate: `bin/rails curriculum:oak_sync` pulls lesson rows, then **post-import hydration** fetches summary, assets, quiz, and transcript for up to `OAK_POST_IMPORT_HYDRATE_MAX` lessons (default **80**) unless you set `OAK_SKIP_POST_IMPORT_HYDRATE=1`. While viewing a lesson, stale data older than **7 days** is refreshed when the token is set.
- Optional tuning: `OAK_IMPORT_LIMIT=5` caps lessons per subject during sync; `OAK_POST_IMPORT_HYDRATE_MAX=0` skips the hydration pass; `OAK_POST_IMPORT_HYDRATE_SLEEP` controls delay between hydrate calls (seconds).

## Tests

```bash
bin/rails test
```

## Deploy

See [`docs/plan/DEPLOYMENT_KAMAL.md`](docs/plan/DEPLOYMENT_KAMAL.md) for Kamal deployment to a DigitalOcean droplet with a Namecheap subdomain (Docker, Let’s Encrypt, persistent `storage/` volume). Repo root must contain `Gemfile` and `Dockerfile` (flat layout).

## Stack

- Ruby 4.x, SQLite (`storage/*.sqlite3`), Tailwind 4, Importmap + Turbo + Stimulus, Devise, Kamal config included.
