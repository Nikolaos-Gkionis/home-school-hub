LMS planning docs and Rails 8.1.3 initialization

Context

MASTER_LMS_PLAN.MD defines HomeSchoolHub (HSH) with Ruby 4.0.2, Rails 8.1.3, SQLite via litestack, Tailwind, Devise, curriculum iframe + progress tracking, themed UX, gamification, and ONCE (TUI-based Docker app host).

The master file’s “Implementation Instructions” say to use a planning/ directory and names ARCHITECT_PLAN.md, DESIGNER_PLAN.md, GAMIFICATION_PLAN.md, DEPLOYMENT_ONCE.md. You asked for docs/plan/ — use that folder and keep those four filenames so the docs stay easy to grep and match the master checklist.



Part 1: Create docs/plan/ and four markdown files

Each file should expand the bullet points from the master plan into concrete tasks, plus migration sketches, model/service outlines, and small code snippets (routes, Stimulus/Turbo patterns, Dockerfile fragments) so implementers can execute without re-deriving design.

1. docs/plan/ARCHITECT_PLAN.md — Tech Architect





Stack lock-in: Ruby 4.0.2, Rails 8.1.3, SQLite + litestack (where DB lives in dev vs prod; Litestack config entry points).



Data model: lessons (fields for Oak Academy Year 7: e.g. title, external_url, subject, unit, position, timestamps); relationships to users / completions as needed for ProgressTracker.



Auth: Devise installation checklist (User model, views, mailer env for later ONCE SMTP vars).



Curriculum: Strategy to scrape/seed Oak URLs (Rake task or service class outline; idempotent seeds).



App features: DashboardController#show embedding external content via <iframe> (security note: sandbox/CSP if applicable).



ProgressTracker: Service API (e.g. mark_complete(user, lesson)), Turbo Stream broadcasts, where to call from UI.



Ractors (optional/advanced): One short subsection on using Ractors only for CPU-bound batch work on curriculum data (not for DB or request cycle), to match the master plan without over-engineering the first slice.

2. docs/plan/DESIGNER_PLAN.md — UX/UI Designer





Layout: Application layout with fixed left nav + scrollable main; responsive collapse rules for small screens.



ThemeManager: Rails helper or Ruby object + CSS custom properties mapped into Tailwind (e.g. theme-* utilities or arbitrary values).



Three presets: “Cosmic Voyager,” “Forest Ranger,” “Cyberpunk Scholar” — per theme: palette variables, typography hints, nav/active states.



Persistence: Migration adding current_theme (string) to users; controller/update flow (Turbo or classic form); default theme for new users.

3. docs/plan/GAMIFICATION_PLAN.md — LMS / gamification





Schema: badges, achievements (or join table user_badges), fields for rule keys and metadata.



Rules:  





Daily Hero: 3 distinct lesson completions within rolling 24 hours (define “completion” event source = ProgressTracker).  



Subject Master: “full unit” = all lessons in a unit for a subject completed (define query).



UI: confetti-canvas integration points (after award / milestone); weekly streak + fire icon in left nav (data source: streak calculator service or cached column).



Idempotency: Do not double-award the same badge for the same scope.

4. docs/plan/DEPLOYMENT_ONCE.md — ONCE.com TUI deployment

Base this on the official ONCE expectations (basecamp/once README): Docker image, HTTP on port 80, **/up healthcheck**, persistent data under /storage (Rails also gets **/rails/storage**).

Document explicitly:







ONCE requirement



HSH action





Port 80 in container



Puma/bind and Dockerfile EXPOSE 80 / CMD





/up



Rails 8 default health check — verify it stays enabled in production image





Persistent SQLite



Place DB (and Litestack files if any) under paths included in /storage or document volume layout + DATABASE_URL / storage.yml





Backups



Optional /hooks/pre-backup for SQLite safe copy; align with ONCE backup flow





TUI / dashboard



Install flow: `curl https://get.once.com

Also include: DNS/SSL notes (e.g. Cloudflare “strict”), **SECRET_KEY_BASE** and SMTP env vars ONCE injects, and that custom apps are installed by Docker image path in the TUI (not necessarily a hand-written once.yml in-repo — mention “follow ONCE prompts / exported config if your ONCE version provides it” so the doc stays accurate across ONCE versions).

flowchart LR
  subgraph host [VPS with ONCE TUI]
    once[once daemon]
    docker[Docker]
    vol["/storage volume"]
  end
  subgraph container [HSH container]
    rails[Rails Puma :80]
    sqlite[SQLite under storage]
  end
  once --> docker
  docker --> rails
  vol --> sqlite
  rails -->|GET /up| once



Part 2: Prepare Rails 8.1.3 app initialization (after docs are written)

Prerequisites (document in ARCHITECT or a short README later):





Ruby 4.0.2 and Rails 8.1.3 available via ruby -v / gem install rails -v 8.1.3 (or version manager pins: .ruby-version, Gemfile).



Node/yarn or importmaps per chosen Rails default; Tailwind as per Rails 8 generator.

Suggested rails new shape (exact flags confirmed at generation time against rails new --help for 8.1.3):





App name aligned with master plan (e.g. homeschool_hub or hsh).



**--database=sqlite3** (then add litestack in Gemfile and configure per gem docs).



Include Tailwind if offered as a flag or add via rails tailwindcss:install per 8.1.3 docs.



Skip unused pieces if desired (--skip-test only if you will use RSpec later, etc.).

Immediate post-rails new checklist:





Add gems: devise, litestack (and lock versions in Gemfile).



Run Devise generator; add current_theme when User exists.



Ensure production **/up** and Dockerfile (Rails 8 default Kamal-style Dockerfile is a good starting point) serve port 80 inside the container for ONCE.



Configure Active Storage / DB paths so SQLite file(s) live under the tree that ONCE mounts to **/storage** (or document bind-mount strategy in DEPLOYMENT_ONCE).

Note: The workspace currently contains only MASTER_LMS_PLAN.MD; initialization will create the app at the repo root or in a subdirectory — choose one location when executing (single app in /Users/laptop/Documents/task-days vs. homeschool_hub/ subfolder) to avoid a nested mess.



Deliverables summary







Path



Audience





docs/plan/ARCHITECT_PLAN.md



Architect





docs/plan/DESIGNER_PLAN.md



UX Designer





docs/plan/GAMIFICATION_PLAN.md



LMS Expert





docs/plan/DEPLOYMENT_ONCE.md



ONCE TUI deployment

Folder discrepancy: Master says planning/; your request says docs/plan/. This plan uses **docs/plan/** only.