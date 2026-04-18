# Namecheap DNS + ONCE: `task-days.com` (Fizzy) and `homeschool.task-days.com` (HomeSchoolHub)

This guide walks you through **Namecheap DNS** for a single domain and **ONCE** on your VPS so that:

- **Fizzy** (ONCE’s stock/catalog app) answers at **`https://task-days.com`** (and optionally **`https://www.task-days.com`**).
- **HomeSchoolHub** (your custom Docker app) answers at **`https://homeschool.task-days.com`**.

It assumes one ONCE server with **one public IPv4 address** (and optionally IPv6). All hostnames share that IP; **ONCE’s reverse proxy** routes traffic to the correct app using the **hostname** (HTTP `Host` header / TLS SNI).

For HomeSchoolHub-specific container expectations (port `80`, `GET /up`, persistent storage), see [`DEPLOYMENT_ONCE.md`](DEPLOYMENT_ONCE.md).

---

## 1. Concepts (quick mental model)

| Idea | Plain-language meaning |
|------|-------------------------|
| **DNS** | Tells the internet which server IP belongs to a name like `task-days.com`. |
| **A record** | Maps a name to an **IPv4** address (e.g. `203.0.113.50`). |
| **AAAA record** | Maps a name to an **IPv6** address. |
| **TTL** | How long resolvers cache your record. Lower = faster changes, more DNS queries. |
| **Apex / root** | The bare domain: `task-days.com` (often shown as `@` in DNS panels). |
| **Subdomain** | A prefix: `homeschool.task-days.com` (host label is usually `homeschool`). |
| **ONCE** | Runs Docker apps on your VPS and typically terminates **HTTPS** and forwards to the right container per hostname. |

**Why both apps can use the same IP:** Browsers send the hostname with each request. ONCE listens on ports **80/443** on the server and dispatches to **Fizzy** vs **HomeSchoolHub** based on that hostname.

---

## 2. Prerequisites checklist

Complete these **before** editing DNS, or you will chase propagation issues:

1. **VPS provisioned** and reachable via SSH (from your provider or home network test).
2. **ONCE installed** on that VPS using the current official flow (commonly `curl https://get.once.com` — use whatever ONCE shows in their docs at install time).
3. **Server IPv4** copied from your VPS panel (and **IPv6** if your VPS includes it and you want AAAA records).
4. **Decide www behavior:**  
   - **Option A:** `www.task-days.com` also shows Fizzy (recommended if you like both URLs).  
   - **Option B:** Only apex `task-days.com` (simpler; you can add `www` later).

---

## 3. Namecheap: open the right DNS panel

1. Log in to [Namecheap](https://www.namecheap.com/).
2. Go to **Domain List** → select **`task-days.com`** → **Manage**.
3. Open the **Advanced DNS** tab.  
   - You want to edit records here, not the simple “Redirect Domain” page, unless you intentionally use redirects.

**If you use Namecheap’s “BasicDNS”:** Advanced DNS is the right place.

**If the domain uses another DNS host** (Cloudflare, etc.): perform the *same record types* there instead of Namecheap; the concepts do not change.

---

## 4. Namecheap records to add (recommended layout)

Use your **ONCE server’s public IPv4** everywhere you see `YOUR_ONCE_IPV4` below.  
If you have IPv6, add matching **AAAA** rows with `YOUR_ONCE_IPV6`.

### 4.1 Apex domain → Fizzy (`task-days.com`)

| Type | Host | Value | TTL |
|------|------|-------|-----|
| **A** | `@` | `YOUR_ONCE_IPV4` | Automatic (or 5–30 min while testing) |

**What this does:** Visitors who type `task-days.com` resolve to your ONCE server.

### 4.2 Optional: `www` → same server (also Fizzy)

Pick **one** approach (do not duplicate conflicting `www` records):

**Approach 1 — A record (simple, very common on Namecheap)**

| Type | Host | Value | TTL |
|------|------|-------|-----|
| **A** | `www` | `YOUR_ONCE_IPV4` | Automatic |

**Approach 2 — CNAME (only if you have no other `www` conflicts)**

| Type | Host | Value | TTL |
|------|------|-------|-----|
| **CNAME** | `www` | `task-days.com.` | Automatic |

> Note: Some DNS providers require a trailing dot on the CNAME target (`task-days.com.`). Namecheap often accepts `task-days.com` and normalizes it.

### 4.3 Subdomain → HomeSchoolHub (`homeschool.task-days.com`)

| Type | Host | Value | TTL |
|------|------|-------|-----|
| **A** | `homeschool` | `YOUR_ONCE_IPV4` | Automatic |

Optional mirror for IPv6-only clients:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| **AAAA** | `homeschool` | `YOUR_ONCE_IPV6` | Automatic |

### 4.4 Optional: AAAA for apex and `www`

If your VPS has a stable IPv6 and your provider expects it:

| Type | Host | Value |
|------|------|-------|
| **AAAA** | `@` | `YOUR_ONCE_IPV6` |
| **AAAA** | `www` | `YOUR_ONCE_IPV6` |

Skip AAAA if you are unsure — **A records alone are enough** for a working site.

---

## 5. Namecheap pitfalls (read this once)

- **Conflicting records:** Remove or disable old **A**, **AAAA**, or **CNAME** rows for `@`, `www`, or `homeschool` that point somewhere else (parking pages, old host, Shopify, etc.). Only one “winner” should exist per name.
- **Email (MX):** If you use email on this domain, **do not delete MX / TXT mail authentication** records unless you know what you are doing. Web **A** records for `@` do not replace **MX**; they can coexist.
- **URL redirect vs DNS:** A “redirect” in Namecheap is not a substitute for an **A** record to your VPS unless you *want* a redirect service in the middle.
- **Propagation:** Changes can take minutes to a few hours. Lower TTL during setup, raise later if you like.

---

## 6. Verify DNS before touching ONCE TLS

From your laptop (any OS), after saving records:

```bash
dig +short task-days.com A
dig +short www.task-days.com A
dig +short homeschool.task-days.com A
```

You want all of these to return **`YOUR_ONCE_IPV4`** (and matching AAAA if you added them).

Online checkers are fine too; the goal is **consistent answers worldwide** before you rely on automatic HTTPS.

---

## 7. ONCE setup: two apps, two hostnames

Exact menu labels change across ONCE versions, but the **sequence** is stable:

### 7.1 Install / open ONCE on the VPS

1. SSH into the server.
2. Complete ONCE installation per official instructions.
3. Open the ONCE **TUI** or **web dashboard** (whatever your install provides).

Keep the server firewall allowing **80/tcp** and **443/tcp** from the internet unless ONCE docs say otherwise.

### 7.2 Deploy **Fizzy** (stock/catalog app)

1. In ONCE, choose **Add app** / **Install** / equivalent.
2. Select **Fizzy** from the catalog (stock application).
3. Assign **primary hostname(s)**:
   - **`task-days.com`**
   - If using www: also **`www.task-days.com`**
4. Finish the wizard. ONCE should pull/build the image and start the container.
5. When prompted for **TLS / HTTPS**, enable it for those hostnames once DNS resolves to this server.

**Smoke test (after ONCE reports healthy):**

```bash
curl -I https://task-days.com
```

You expect a **2xx/3xx** response, not a certificate error. If you get TLS errors, DNS is still wrong somewhere or the cert was requested before DNS propagated.

### 7.3 Deploy **HomeSchoolHub** (custom Docker app)

1. In ONCE, **add another application** (do not reuse Fizzy’s container).
2. Choose **custom** / **Docker image** (wording varies) and supply your image reference, e.g. `ghcr.io/your-org/home-school-hub:tag` or whatever you publish.
3. Assign hostname: **`homeschool.task-days.com`** only.
4. **Persistent volume:** mount to the path your image expects. This repo’s ONCE notes emphasize a single writable storage root — see [`DEPLOYMENT_ONCE.md`](DEPLOYMENT_ONCE.md) for `/storage` vs `/rails/storage` conventions and SQLite layout.
5. **Environment variables** in ONCE (not only a local `.env`), minimally:
   - `RAILS_ENV=production`
   - `SECRET_KEY_BASE` (strong random value)
   - `OAK_API_TOKEN` (if you use Oak sync)
   - Any SMTP vars when you enable mailers
6. **Health check path:** `GET /up` (Rails default).
7. **Container port:** align with ONCE’s expectations (this project targets **port 80** inside the container per `DEPLOYMENT_ONCE.md`).

**Smoke test:**

```bash
curl -f https://homeschool.task-days.com/up
```

---

## 8. Order of operations (recommended)

1. Install ONCE on VPS; confirm it is reachable on IP (dashboard/TUI).
2. Add **Namecheap A records** (`@`, `homeschool`, optional `www`).
3. Wait until `dig` shows correct IPs everywhere you care about.
4. In ONCE, enable **HTTPS** for **Fizzy** on `task-days.com` (and `www` if used).
5. Deploy **HomeSchoolHub** and enable **HTTPS** for `homeschool.task-days.com`.
6. Run app-level checks (login, boards/cards for Fizzy; `/up` and main flows for HomeSchoolHub).

---

## 9. Troubleshooting (symptom → likely cause)

| Symptom | Likely cause | What to check |
|--------|----------------|---------------|
| Wrong site on apex | Old A record or CDN | Namecheap **Advanced DNS** for `@`; remove stale A/CNAME. |
| `www` does not match apex | Missing `www` A/CNAME | Add `www` record as in §4.2. |
| TLS cert fails / wrong domain | DNS pointed elsewhere when cert was issued | Fix DNS, then **reissue / renew** cert in ONCE. |
| Subdomain hits Fizzy | Hostname not assigned to HSH app in ONCE | Map **`homeschool.task-days.com`** only to the HSH container. |
| 502 / gateway error | Container not listening on expected port / unhealthy | Logs in ONCE; `curl` from server to container; verify `/up`. |

---

## 10. Related docs in this repository

- [`DEPLOYMENT_ONCE.md`](DEPLOYMENT_ONCE.md) — HomeSchoolHub container checklist (port 80, `/up`, storage, secrets).
- [`ONCE_SUBDOMAIN_DEPLOYMENT_PLAN.md`](ONCE_SUBDOMAIN_DEPLOYMENT_PLAN.md) — broader rollout phases (Oak sync, backups, go-live).

---

## 11. If you tell a beginner “the one thing to remember”

**DNS sends people to your server’s IP; ONCE uses the hostname to choose Fizzy vs HomeSchoolHub.**  
Get the **A records** right first, then let ONCE issue **HTTPS** certificates for each hostname.
