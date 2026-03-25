# Project: HomeSchoolHub (HSH)
## Stack: Ruby 4.0.2, Rails 8.1.3, SQLite3 (Litestack), Tailwind CSS
## Deployment: ONCE TUI (Open Network Container Executor)

### 1. Role: Tech Architect (System & Data)
- **Engine:** Rails 8.1.3 with Ruby 4.0.2 (utilizing Ractors for parallel processing of curriculum data).
- **Database:** SQLite3 using the `litestack` gem for production-grade performance.
- **Authentication:** Devise (Email + Password).
- **Curriculum Integration:** - Scrape/Seed Oak Academy Year 7 URLs into a `Lessons` table.
    - Implement an `<iframe>` in the `Dashboard#show` view.
    - Create a `ProgressTracker` service to handle "Mark as Complete" via Turbo Streams.

### 2. Role: UX/UI Designer (Theming & Layout)
- **Layout:** Standard dashboard with a fixed Left-Hand Navigation and a large Right-Hand Main Area.
- **Dynamic Theming:** Implement a `ThemeManager` using CSS Variables and Tailwind.
- **Themes:** Create three presets: "Cosmic Voyager," "Forest Ranger," and "Cyberpunk Scholar."
- **User Preference:** Save `current_theme` to the `User` model so it persists across devices.

### 3. Role: LMS Gamification Expert (Engagement)
- **Badge Engine:** A `Badge` and `Achievement` system.
- **Logic:** - Award "Daily Hero" for completing 3 lessons in 24 hours.
    - Award "Subject Master" for finishing a full Unit.
- **Visuals:** Use `confetti-canvas` for milestone celebrations and a "Weekly Streak" fire icon in the LH Nav.

### 4. Role: DevOps Specialist (Once.com TUI Deployment)
- **Deployment Strategy:** Use the **ONCE TUI** method.
- **Configuration:** Setup the `once.yml` or relevant container configuration for the VPS.
- **Infrastructure:** Ensure the SQLite3 database is properly volumed so data persists through container restarts.
- **Tooling:** Enable the ONCE dashboard for monitoring RAM/CPU usage and scheduled backups.

---

### Implementation Instructions for Cursor:
1. Create a `planning/` directory.
2. Generate four separate markdown files: `ARCHITECT_PLAN.md`, `DESIGNER_PLAN.md`, `GAMIFICATION_PLAN.md`, and `DEPLOYMENT_ONCE.md`.
3. Each file must contain specific code snippets, migration structures, and step-by-step implementation tasks.