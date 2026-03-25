# HomeSchoolHub — UX/UI Designer Plan

Layout, **ThemeManager**, three visual presets, Tailwind integration, and persisted `current_theme` on **User**.

---

## 1. Layout structure

- **Application layout:** Fixed **left navigation** (width ~14–16rem desktop), **scrollable main** content (lesson iframe + chrome).
- **Small screens:** Collapse nav to **hamburger** + slide-over or top sheet; main area full width.
- **Landmarks:** `<nav aria-label="Primary">` for LH nav; `<main id="main-content">` for focus management.

### HTML sketch (ERB)

```erb
<body class="theme-cosmic-voyager min-h-screen flex">
  <nav class="... w-64 shrink-0 border-r ...">...</nav>
  <main class="flex-1 overflow-y-auto p-4 md:p-6">
    <%= yield %>
  </main>
</body>
```

Use Stimulus controller `nav--toggle` for mobile menu if needed.

---

## 2. ThemeManager

**Goal:** One place that maps **preset name** → **CSS custom properties** consumed by Tailwind arbitrary values or `@apply` in a single `app.css` layer.

### Option A — Ruby helper + data attributes

`app/helpers/theme_helper.rb`:

```ruby
module ThemeHelper
  THEMES = %w[cosmic_voyager forest_ranger cyberpunk_scholar].freeze

  def theme_body_class
    "theme-#{current_user&.current_theme.presence || 'cosmic_voyager'}"
  end
end
```

Layout: `<body class="<%= theme_body_class %> ...">`

### Option B — `ThemeManager` PORO

`app/models/theme_manager.rb` (or `app/lib/theme_manager.rb`):

```ruby
class ThemeManager
  PRESETS = {
    "cosmic_voyager" => { css_class: "theme-cosmic-voyager" },
    "forest_ranger" => { css_class: "theme-forest-ranger" },
    "cyberpunk_scholar" => { css_class: "theme-cyberpunk-scholar" }
  }.freeze

  def self.class_for(key)
    PRESETS.dig(key.to_s, :css_class) || PRESETS["cosmic_voyager"][:css_class]
  end
end
```

---

## 3. CSS custom properties + Tailwind

**File:** `app/assets/stylesheets/application.tailwind.css` (or project equivalent)

Define three root scopes:

```css
.theme-cosmic-voyager {
  --color-bg: #0f0c29;
  --color-surface: #1a1744;
  --color-accent: #a78bfa;
  --color-text: #e2e8f0;
  --font-display: "Syne", system-ui, sans-serif;
}

.theme-forest-ranger {
  --color-bg: #1c2e1e;
  --color-surface: #24382a;
  --color-accent: #86efac;
  --color-text: #ecfdf5;
  --font-display: "Fraunces", Georgia, serif;
}

.theme-cyberpunk-scholar {
  --color-bg: #0d0221;
  --color-surface: #1a0b2e;
  --color-accent: #f472b6;
  --color-text: #fae8ff;
  --font-display: "Orbitron", sans-serif;
}
```

**Tailwind usage:** `bg-[var(--color-bg)]`, `text-[var(--color-text)]`, `border-[var(--color-surface)]`, or extend `theme` in `tailwind.config.js` with `colors.hsh.bg: 'var(--color-bg)'` etc. for `bg-hsh-bg` utilities.

### Nav / active states

- **Default link:** muted foreground `opacity-80`
- **Active:** `border-l-4 border-[var(--color-accent)]` + full opacity + `font-medium`
- **Focus:** visible ring using `var(--color-accent)`

---

## 4. Three presets (summary)

| Preset key | Display name | Mood |
|------------|--------------|------|
| `cosmic_voyager` | Cosmic Voyager | Deep space, violet accents |
| `forest_ranger` | Forest Ranger | Woodland greens, calm |
| `cyberpunk_scholar` | Cyberpunk Scholar | Neon magenta/cyan hints on dark |

Load **Google Fonts** in layout `<head>` for display faces above (subset weights to reduce payload).

---

## 5. Persistence — `current_theme`

### Migration

```ruby
add_column :users, :current_theme, :string, default: "cosmic_voyager", null: false
```

### Validation (User model)

```ruby
validates :current_theme, inclusion: { in: ThemeManager::PRESETS.keys }
# or %w[cosmic_voyager forest_ranger cyberpunk_scholar]
```

### Controller + flow

- **Routes:** `resource :theme, only: [:update]` → `ThemesController#update`
- **Params:** `params.require(:user).permit(:current_theme)` or `params.permit(:current_theme)`
- **Update:** `current_user.update!(current_theme: ...)` then redirect back or Turbo Stream replace theme picker partial.

**Turbo-friendly form:**

```erb
<%= form_with model: current_user, url: theme_path, method: :patch do |f| %>
  <%= f.select :current_theme, theme_options %>
<% end %>
```

**Classic:** Same with `data: { turbo: false }` if avoiding Turbo for this form.

### Default for new users

Migration default `cosmic_voyager` ensures new rows are valid; Devise registration need not set theme unless you expose it on sign-up.

---

## 6. Designer implementation checklist

1. Build responsive layout + nav partial  
2. Add ThemeManager + CSS variables for three `.theme-*` classes  
3. Migration `current_theme` + User validation  
4. ThemesController + settings UI in nav footer  
5. Verify contrast (WCAG) for text on `--color-bg` / `--color-surface`  
6. Coordinate with GAMIFICATION_PLAN for streak/fire icon placement in nav
