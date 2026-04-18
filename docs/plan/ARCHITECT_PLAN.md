# HomeSchoolHub — Tech Architect Plan

Expands [MASTER_LMS_PLAN.MD](../../MASTER_LMS_PLAN.MD) into executable tasks for stack, data, auth, curriculum, progress, and optional Ractors.

---

## 1. Stack lock-in

| Piece | Version / choice | Notes |
|--------|------------------|--------|
| Ruby | 4.0.2 (target); CI/dev may use 4.0.x) | Pin `.ruby-version` + Gemfile `ruby "~> 4.0.0"` |
| Rails | 8.1.3 | `gem "rails", "~> 8.1.3"` |
| DB | SQLite3 + **litestack** (when compatible) | App currently uses plain `sqlite3` adapter; **litestack 0.4.3** sets `sqlite3_production_warning`, which **Rails 8.1 removed** — re-add the gem when upstream supports 8.1 or patch the railtie. |

### Litestack entry points

- **Gemfile:** `gem "litestack"` (commented out in generated app until compatible; lock patch version after `bundle update`).
- **Config:** Follow [litestack](https://github.com/oldmoe/litestack) README for Rails 8 — typically `config/database.yml` continues to use `adapter: sqlite3`; litestack may add queue/cache integration. Confirm current gem docs for `config/application.rb` requires and `config/environments/production.rb` Litesearch/Litequeue if used.
- **Where DB files live:**  
  - **Development:** `config/database.yml` → `database: storage/development.sqlite3` (keeps DB inside app tree for easy Kamal/Docker bind-mount of one `storage/` root).  
  - **Production:** Same relative pattern; `config/deploy.yml` mounts a Docker volume at `/rails/storage` so `storage/production*.sqlite3` persist—see [`DEPLOYMENT_KAMAL.md`](DEPLOYMENT_KAMAL.md).

### Prerequisites checklist

- `ruby -v` → 4.0.x  
- `gem install rails -v 8.1.3` (or Bundler-only install from app Gemfile)  
- Node + Tailwind pipeline per Rails 8 (`cssbundling` / `tailwindcss-rails` as generated)

---

## 2. Data model — `lessons` and progress

### `lessons` (Oak Academy Year 7–oriented)

| Column | Type | Purpose |
|--------|------|---------|
| `title` | string | Display name |
| `external_url` | string | Oak (or other) lesson URL for iframe |
| `subject` | string | e.g. `mathematics`, `english` |
| `unit` | string | Unit label within subject |
| `position` | integer | Sort order within unit |
| `created_at` / `updated_at` | datetime | Rails defaults |

**Indexes:** `[subject, unit, position]` for listing.

### Completions / users

- **Devise `users`** table (see Auth section).
- **`lesson_completions`** (or `progress_events`):  
  - `user_id`, `lesson_id`, `completed_at` (datetime), optional `metadata` (json) for audits.

**Relationships:**

- `User has_many :lesson_completions`  
- `Lesson has_many :lesson_completions`  
- `User has_many :completed_lessons, through: :lesson_completions, source: :lesson`

### Migration sketch

```ruby
# db/migrate/XXXXXXXX_create_lessons.rb
create_table :lessons do |t|
  t.string :title, null: false
  t.string :external_url, null: false
  t.string :subject, null: false
  t.string :unit, null: false
  t.integer :position, default: 0, null: false
  t.timestamps
end
add_index :lessons, [:subject, :unit, :position]

# db/migrate/XXXXXXXX_create_lesson_completions.rb
create_table :lesson_completions do |t|
  t.references :user, null: false, foreign_key: true
  t.references :lesson, null: false, foreign_key: true
  t.datetime :completed_at, null: false
  t.timestamps
end
add_index :lesson_completions, [:user_id, :lesson_id], unique: true
```

---

## 3. Auth — Devise checklist

1. Add to Gemfile: `gem "devise"` → `bundle install`
2. `bin/rails generate devise:install`
3. Set `config.action_mailer.default_url_options` in `config/environments/development.rb` (host/port).
4. `bin/rails generate devise User` (add `current_theme` in same migration or follow-up — see DESIGNER_PLAN).
5. Run migrations.
6. Add `before_action :authenticate_user!` to authenticated controllers (e.g. `DashboardController`).
7. **Mailer / Kamal:** Production SMTP vars (`SMTP_ADDRESS`, etc.) are set in `config/deploy.yml` / `.kamal/secrets` and passed into the container; keep `config/environments/production.rb` reading `ENV` for delivery options when enabling confirmable/recoverable.

---

## 4. Curriculum — seed Oak URLs

**Strategy:** Idempotent seed, not a blind scrape on every boot.

- **Service object:** `app/services/oak_curriculum_seed.rb` — loads a YAML or Ruby hash of known Year 7 lesson rows; `Lesson.find_or_initialize_by(external_url: ...)` then set attributes; `save!`.
- **Rake task:** `lib/tasks/curriculum.rake`

```ruby
# lib/tasks/curriculum.rake
namespace :curriculum do
  desc "Idempotent seed of Oak (or placeholder) lessons"
  task seed: :environment do
    OakCurriculumSeed.call
  end
end
```

- **Data source:** Start with static `config/curriculum/oak_year7.yml` (maintainable URLs). Replace with HTTP fetch + parser only if legally/technically approved; CPU-heavy parsing is a candidate for Ractors (below).

---

## 5. Dashboard + iframe

- **Route:** `root` or `dashboard#show` after sign-in.
- **Controller:** `DashboardController#show` — loads `@lesson` (from params or default first lesson).
- **View:** `<iframe src="<%= @lesson.external_url %>" title="Lesson" class="w-full min-h-[70vh]"></iframe>`
- **Security:** Prefer **sandbox** attribute for least privilege, e.g. `sandbox="allow-scripts allow-same-origin allow-popups allow-forms"` — tune per Oak requirements. Add **Content-Security-Policy** headers in `config/initializers/content_security_policy.rb` for `frame_src` to Oak domains only in production.

---

## 6. ProgressTracker — service API + Turbo

**Service:** `app/services/progress_tracker.rb`

```ruby
class ProgressTracker
  def self.mark_complete(user:, lesson:)
    completion = user.lesson_completions.find_or_initialize_by(lesson: lesson)
    return completion if completion.persisted?
    completion.completed_at = Time.current
    completion.save!
    broadcast_dashboard(user)
    completion
  end

  def self.broadcast_dashboard(user)
    # Turbo::StreamsChannel.broadcast_replace_to(...)
  end
end
```

**Call sites:** `LessonCompletionsController#create` (POST) or Turbo-powered button in dashboard partial.

**Turbo Stream:** Target a DOM id (e.g. `lesson_#{lesson.id}_status`) with `turbo_stream.replace` / `update` after `mark_complete`.

**Route snippet:**

```ruby
resources :lesson_completions, only: [:create]
```

---

## 7. Ractors (optional, advanced)

**Use only for CPU-bound batch work** on curriculum data (e.g. normalizing large JSON exports), **not** for DB I/O or per-request handling.

- Spawn Ractor with plain data; return serializable results; main thread writes to DB.
- Example: `Ractor.new(big_array) { |data| data.map { ... heavy pure transform ... } }`

---

## 8. Implementation order (architect track)

1. Rails app + SQLite paths + litestack  
2. Devise + User + `current_theme`  
3. `lessons` + `lesson_completions` migrations  
4. Seed task + sample lessons  
5. `DashboardController#show` + iframe + CSP/sandbox  
6. `ProgressTracker` + Turbo Stream updates  
7. Wire gamification hooks (see GAMIFICATION_PLAN) after completions exist
