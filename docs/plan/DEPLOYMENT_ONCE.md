# HomeSchoolHub — ONCE.com TUI Deployment

Maps [ONCE](https://once.com) expectations to HSH actions: Docker, **port 80**, **`/up`**, persistent **`/storage`**, backups, DNS/SSL, secrets.

---

## ONCE requirement → HSH action

| ONCE requirement | HSH action |
|------------------|------------|
| **Port 80 in container** | Puma binds `0.0.0.0:80` in container; Dockerfile `EXPOSE 80`; `CMD` starts Rails/Puma on 80 (see Dockerfile fragment below). |
| **`/up` health check** | Rails 8 default **`GET /up`** — keep enabled in production; do not disable in `config/environments/production.rb`. Verify in built image with `curl -f http://127.0.0.1/up`. |
| **Persistent data under `/storage`** | Mount host/volume to container **`/storage`** (ONCE convention). Place SQLite DB (and litestack files if any) under paths included in that mount, e.g. **`/storage/rails/db/production.sqlite3`** or symlink `storage/` → under `/storage`. |
| **Rails Active Storage** | Default `config/storage.yml` disk path should live under **`/rails/storage`** or unified under **`/storage/rails/storage`** so uploads survive restarts. |
| **Backups** | Optional ONCE **`/hooks/pre-backup`**: copy SQLite safely (`sqlite3 .backup` or file copy when app quiesced); align with ONCE backup schedule in TUI. |
| **TUI / dashboard** | Install via ONCE flow: **`curl https://get.once.com`** (complete URL per current ONCE docs) — follow interactive installer. Custom apps: point TUI at **Docker image** (registry/repo:tag) or build context path ONCE expects for your version. |
| **Secrets** | **`SECRET_KEY_BASE`** set by ONCE or your env layer. **SMTP** variables ONCE injects — map in `production.rb` when enabling mailers. |

> Custom apps are often installed by **Docker image path** in the TUI, not necessarily a hand-written `once.yml` in-repo. Follow ONCE prompts and any **exported config** your ONCE version provides.

---

## DNS / SSL

- Point DNS A/AAAA to VPS.
- Terminate TLS at reverse proxy or ONCE edge if offered; if **Cloudflare**, use **Full (strict)** with valid origin cert.
- Ensure health checks hit **`/up`** over the same scheme/port ONCE uses internally (often HTTP inside Docker network).

---

## Dockerfile fragment (port 80)

```dockerfile
EXPOSE 80
ENV RAILS_ENV=production
# Bind Puma to 80 inside container (requires non-privileged binding or setcap — many images use PORT=80 with a non-root user via capabilities)
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "80"]
```

If the image runs as non-root and cannot bind 80, use **`PORT=3000`** internally and map **host 80 → container 3000** in ONCE/docker port mapping (confirm ONCE expects app listening on 80 *inside* container per their checklist).

---

## SQLite + Litestack paths

**Example `config/database.yml` production:**

```yaml
production:
  adapter: sqlite3
  database: /storage/rails/db/production.sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
```

Ensure **`mkdir -p`** in entrypoint for `/storage/rails/db` before boot.

**Volume layout (conceptual):**

- Host: `/var/lib/once/hsh-storage` → Container: `/storage`  
- App writes: `/storage/rails/db/*.sqlite3`, `/storage/rails/storage/*` (Active Storage)

Document **`DATABASE_URL`** override if ONCE sets it instead of `database.yml`.

---

## Environment variables (reference)

| Variable | Purpose |
|----------|---------|
| `SECRET_KEY_BASE` | Rails session/signing |
| `RAILS_LOG_LEVEL` | Optional |
| `SMTP_*` / `MAILER_*` | Devise mailers when enabled |
| `DATABASE_URL` | Optional SQLite path override |

---

## Architecture (flowchart)

```mermaid
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
```

---

## Pre-deploy checklist

1. Build production image locally; `curl -f http://localhost:PORT/up`  
2. Confirm SQLite directory writable on volume  
3. Run migrations in entrypoint or one-off task before traffic  
4. Set `SECRET_KEY_BASE`  
5. Configure ONCE health check → `/up`  
6. Test backup hook with SQLite copy
