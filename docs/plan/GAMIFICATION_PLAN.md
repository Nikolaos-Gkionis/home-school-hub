# HomeSchoolHub — LMS / Gamification Plan

Badges, achievements, rules (**Daily Hero**, **Subject Master**), confetti + streak UI, and **idempotent** awards.

---

## 1. Schema

### `badges`

| Column | Type | Notes |
|--------|------|--------|
| `key` | string, unique | Machine id, e.g. `daily_hero`, `subject_master` |
| `name` | string | Display name |
| `description` | text | Shown in UI |
| `timestamps` | | |

### `user_badges` (join)

| Column | Type | Notes |
|--------|------|--------|
| `user_id` | references | |
| `badge_id` | references | |
| `metadata` | json, optional | e.g. `{ "subject": "mathematics", "unit": "Unit 3" }` |
| `awarded_at` | datetime | When rule fired |
| `timestamps` | | |

**Unique index:** `[user_id, badge_id, scope_key]` where `scope_key` is a nullable string — for global badges use `NULL` or a single value; for per-unit Subject Master use `"mathematics:Unit 3"` so the same badge type can repeat per scope.

*Alternative:* `achievements` table as single source with `rule_key` + `scope_key` + `user_id` + unique constraint on `[user_id, rule_key, scope_key]`.

### Migration sketch

```ruby
create_table :badges do |t|
  t.string :key, null: false, index: { unique: true }
  t.string :name, null: false
  t.text :description
  t.timestamps
end

create_table :user_badges do |t|
  t.references :user, null: false, foreign_key: true
  t.references :badge, null: false, foreign_key: true
  t.string :scope_key # e.g. "subject:math|unit:Algebra"
  t.json :metadata, default: {}
  t.datetime :awarded_at, null: false
  t.timestamps
end
add_index :user_badges, [:user_id, :badge_id, :scope_key], unique: true, name: "index_user_badges_unique_award"
```

Seed `badges` rows in `db/seeds.rb` or dedicated task.

---

## 2. Rules

### Event source

All rules listen to **lesson completion** created by `ProgressTracker.mark_complete` (or equivalent). After successful save, call **`Gamification::Engine.award_for_completion(user, lesson)`** (single entry point).

### Daily Hero

- **Rule:** At least **3 distinct lessons** completed within a **rolling 24 hours** (now − 24h).
- **Query idea:** `user.lesson_completions.where(completed_at: 24.hours.ago..).distinct.count(:lesson_id) >= 3`
- **Badge:** `badges.key = daily_hero` with **global** scope (`scope_key` nil). Award once per calendar strategy: plan says “rolling 24h” — typically award when threshold first crossed; idempotency = one row per user for this badge **or** reset daily (product choice). **Simplest idempotent:** one `user_badges` row per user for `daily_hero` ever; **rolling variant:** use `scope_key = date bucket` e.g. `scope_key: Time.current.utc.to_date.to_s` and unique index allows one per day.

*Recommendation for first slice:* `scope_key = "day:#{Date.current}"` in UTC so you can re-earn next day without duplicate same day.

### Subject Master

- **Definition:** All lessons in the same **`subject` + `unit`** for that user are completed.
- **Query:** For `lesson.subject` and `lesson.unit`, compare:

```ruby
total = Lesson.where(subject: s, unit: u).count
done = user.lesson_completions.joins(:lesson).where(lessons: { subject: s, unit: u }).distinct.count(:lesson_id)
award if total.positive? && done >= total
```

- **Scope key:** `"#{subject}:#{unit}"` for `user_badges` uniqueness so multiple units can each grant Subject Master.

---

## 3. Idempotency

- Use **`find_or_create_by!`** / **`user.user_badges.find_or_initialize_by(badge:, scope_key:)`** — only `save!` if new.
- Wrap in transaction with completion save if needed.

```ruby
def award_badge!(user, badge_key, scope_key: nil, metadata: {})
  badge = Badge.find_by!(key: badge_key)
  user.user_badges.find_or_create_by!(badge: badge, scope_key: scope_key) do |ub|
    ub.awarded_at = Time.current
    ub.metadata = metadata
  end
rescue ActiveRecord::RecordNotUnique
  # concurrent double-submit — ignore
end
```

---

## 4. UI — confetti + streak

### confetti-canvas

- After successful award (Turbo Stream response or Stimulus `award` event), run lightweight confetti from **`confetti-canvas`** or **canvas-confetti** npm package.
- **Integration:** Stimulus `celebration_controller.js` — `connect()` listens for `turbo:after-stream-render` or custom event `hsh:badge-awarded`; calls confetti API once.

### Weekly streak + fire icon (LH nav)

- **Service:** `Gamification::StreakCalculator.call(user)` → `{ current_week_streak: n, active_this_week: true/false }`
- **Definition (suggested):** Count consecutive calendar weeks with ≥1 completion; or “lessons this week” badge only — document chosen rule in code comment.
- **Cache:** Optional `users.weekly_streak_count` updated in same transaction as completion to avoid heavy queries on every page (invalidate on completion).

**Nav partial:** If `current_streak > 0`, show 🔥 + number with `title` tooltip “Weekly streak”.

---

## 5. Turbo Stream broadcasts

- On new `user_badge`, broadcast append to `turbo_stream_from "user_#{user.id}_badges"` toast area, or trigger Stimulus event for confetti only (no duplicate badge row).

---

## 6. Implementation order

1. Migrations + models `Badge`, `UserBadge`  
2. Seed badges  
3. `Gamification::Engine` + hook from `ProgressTracker`  
4. Implement Daily Hero + Subject Master evaluators  
5. Nav streak + confetti Stimulus  
6. Admin/debug page optional: list user badges
