# AA26 Demo Data Manager — Status / Master Reference

**Current version:** v3.0.0
**Source of truth:** `aa26-demo-data-manager-v2.jsx` (~5,000 lines)
**Built artifact:** `demo-data-manager.html` (~327 KB single file, no build step)
**Deployment target:** AA26 server `appaa.cloud.lab` via k3s ingress (Traefik)
**Live URL pattern:** `https://<aa26-host>/demo-manager/`

---

## What This Tool Does (One Paragraph)

Generates realistic synthetic demo data for Netwrix Access Analyzer (AA26) and injects it via Metabase's SQL API into ClickHouse, then configures the AA26 application layer (service accounts → sources → scans → scan executions) via the AA26 REST API. The result: a complete AA26 demo environment that looks like it's been running in production for months, with no real data sources or customer infrastructure required. Designed for Solutions Engineers to spin up compelling demos in 5-15 minutes.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                   AA26 Server (appaa.cloud.lab)                 │
│                                                                 │
│  ┌──────────────┐    ┌──────────────────┐    ┌──────────────┐   │
│  │   Browser    │    │  k3s Cluster     │    │  PostgreSQL  │   │
│  │   (SE user)  │◄───┤  - demo-manager  │    │  (app cfg)   │   │
│  └──────┬───────┘    │    pod (nginx)   │    └──────▲───────┘   │
│         │            │  - AA26 backend  │           │           │
│         │            │  - ClickHouse    │           │ kubectl   │
│         ▼            │  - Metabase      │           │ exec      │
│  https://aa26-host/  └────────▲─────────┘           │           │
│  demo-manager/                │                     │           │
│         │                     │                     │           │
│         │   Same-origin auth  │                     │           │
│         │   (_dspm_session)   │                     │           │
│         │                     │                     │           │
│         │     ┌───────────────┴───────────┐         │           │
│         └────►│ Demo Data Manager (this)  ├─────────┘           │
│               │  - Phase 1-4: ClickHouse  │  (Phase 5 SQL via   │
│               │    INSERTs via Metabase   │   kubectl on user)  │
│               │  - AA26 Config: REST API  │                     │
│               │  - Generate UI            │                     │
│               └───────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

### Three Data Layers
1. **ClickHouse** (analytics) — file/share/perm/activity facts. Populated via Metabase API.
2. **PostgreSQL** (app config) — service accounts, sources, source groups, scans, scan executions. Populated via AA26 REST API + one kubectl-exec'd SQL command for source-group linkage and historical executions.
3. **Embedded Metabase** — runs dashboards/reports on top of ClickHouse.

### Same-Origin Hosting
The tool is deployed as a k3s pod on the AA26 server itself, served via Traefik ingress at `/demo-manager/`. This makes browser auth automatic — the `_dspm_session` cookie is attached to all API calls without manual token handling. Running locally (cross-origin) loses this and disables AA26 Configuration features (still works for ClickHouse-only injection).

---

## File Map

```
~/demo-data-manager/                    (on AA26 server)
├── demo-data-manager.html              # The built single-file app (the artifact users see)
├── demo-manager.yaml                   # k3s manifest (Deployment + Service + IngressRoute)
└── install-demo-manager.sh             # Installer script (install/update/uninstall/status)

(in the project workspace, source of truth)
├── aa26-demo-data-manager-v2.jsx       # Source JSX (~5,000 lines, no build step required)
├── AA26-DemoDataManager-Status.md      # This doc — master reference
├── AA26-DemoDataManager-CHANGELOG.md   # All changes since v2.8.x
├── AA26-DemoDataManager-QuickStart.md  # Tester / SE quick-start guide
├── AA26-DemoDataManager-Deployment.md  # Detailed deploy / k3s pitfalls
├── AA26-DemoDataManager-FutureWork.md  # Roadmap for the "future me"
└── AA26-DemoDataManager-NewChat-Handoff.md  # Latest state for next Claude chat
```

---

## Build / Deploy Pattern

The JSX file is converted to HTML via a simple `sed` concatenation, NOT webpack. This is intentional — keeps zero build dependencies.

```bash
# Validate JSX parses (uses @babel/parser)
node -e "require('@babel/parser').parse(require('fs').readFileSync('aa26-demo-data-manager-v2.jsx','utf8'),{sourceType:'module',plugins:['jsx']})"

# Build HTML
head -12 demo-data-manager.html > new.html
echo 'const {useState, useCallback, useEffect} = React;' >> new.html
sed 's/^import .*;//;s/^export default function App/function App/' aa26-demo-data-manager-v2.jsx >> new.html
echo 'ReactDOM.createRoot(document.getElementById("root")).render(<App/>);' >> new.html
echo '</script></body></html>' >> new.html
mv new.html demo-data-manager.html

# Deploy via installer (preferred)
./install-demo-manager.sh
```

The `head -12` captures the React/Tailwind/Babel CDN includes and the single-line `<style>` block. If you ever need to add CSS, keep the style block ON ONE LINE — multi-line breaks the build script.

---

## Critical Gotchas (Never Lose These)

### Auth & API
- **Cookie name is `_dspm_session`** — NOT `_session_id` as the AA26 docs suggest
- **No API tokens exist** — same-origin browser auth is the only way (or copy the cookie manually for cross-origin testing)

### Service Account POSTs (3 different payload shapes by type)
- `username_password` — both credentials in `parameters.values`
- `client_id_secret` — `client_id` at ROOT, only `client_secret` in `parameters`
- `client_id_certificate` — both `client_id` AND `tenant_id` at ROOT, certificate data in `parameters`

### Sources & Source Groups
- Sources are simple POST: `{name, sourceTypeId, serviceAccountId, connectionParameters}`
- **Source-to-source-group linkage is NOT exposed through the REST API** — requires direct Postgres UPDATE via kubectl-exec (this is what Phase 5 SQL handles)
- There are **7 source-type UUIDs** including a hidden `localgroups` type not listed in `/api/v1/source-types`
  - `localgroups` UUID: `a2f164b5-23c6-4d11-b329-e2f7c9e07974`

### Scans
- Snake_case field names in payloads (not camelCase like the rest of the API)
- **Always `cron_enabled: false`** — otherwise k3s tries to actually run the scan against fake hosts
- Undocumented `sync` scan type exists and works (used for AD/Entra identity sync demos)

### Scan Executions
- **Strict state machine: `pending → running → completed`** — cannot skip
- `total_objects: 0` via API is **server-controlled** — cannot set via API, only via SQL UPDATE
- Multi-execution history (v3.0+) uses INSERT-FROM-SELECT to clone the API-created row with new UUID + backdated timestamps
- **Verified schema:** id, scan_id, scan_type, source_id, status, total_objects, completed_objects, error_details, completed_at, created_at, updated_at, parent_execution_id (nullable), post_processing_key (nullable), started_at

### Metabase / ClickHouse
- Database ID `2` is ClickHouse. Postgres is NOT registered in Metabase.
- INSERT via `/api/dataset` returns `status: 'failed'` with "Select statement did not produce a ResultSet" **even on success** — this is cosmetic, must be ignored
- ClickHouse UUID comparisons require `toString(col) = 'uuid'` or `toUUID('uuid')` — plain string literals fail unpredictably through Metabase
- `_latest` suffix tables are MaterializedViews with independent inner storage — must use `ALTER TABLE ... DELETE WHERE 1=1`, not `TRUNCATE`
- ClickHouse Enum columns are strict (e.g., `item_type` accepts only `SITE`, `LIST`, `LIBRARY`, `LIST_ITEM`)
- `normalized_permissions` is `FixedString(5)` — must be exactly 5 chars
- Non-nullable LowCardinality columns reject NULL — use empty string `''`
- Metabase `/api/card` returns `type: "query"` for GUI-built questions (not `"native"`); to get generated SQL, POST to `/api/card/{id}/query` with empty body and parse `response.data.native_form.query`
- `SYSTEM RELOAD DICTIONARY` cannot be executed via Metabase API user (insufficient permissions); `entities_hier_dict` auto-reloads every 5–35 seconds

### k3s / kubectl
- **ConfigMap updates require `kubectl replace` (not `apply`)** — `apply` fails because the HTML file exceeds the 262 KB annotation size limit
- The `kubectl create configmap ... --dry-run=client -o yaml | kubectl replace -f -` pattern handles this
- **Pod restart after ConfigMap update requires explicit `kubectl rollout restart deployment/demo-manager -n default`** — volume mounts do NOT auto-refresh reliably
- Postgres access pattern: `kubectl exec -i postgres-0 -n access-analyzer -- psql -U postgres -d access_analyzer < ~/file.sql` (use `-i` not `-it` for file-based SQL); heredoc `<< 'EOSQL'` works for inline SQL

### SCP Path Discipline
- **Use trailing slash on target when copying INTO a directory**:
  - ✅ `scp file.html user@host:demo-data-manager/`
  - ✅ `scp file.html user@host:demo-data-manager/file.html` (explicit, unambiguous)
  - ❌ `scp file.html user@host:demo-data-manager` (creates a FILE *named* `demo-data-manager` if the directory doesn't exist)
- The installer script defends against this and so do the in-app Step 6/7 instructions

---

## Configuration Defaults (DEFAULT_CONFIG)

```javascript
global: {
  vertical: "generic",
  domainName: "ACME",
  domainFqdn: "acme.local",
  sidBase: "S-1-5-21-3298745201-1587429463-2190384756",
  tenantId: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  historyMonths: 2,           // Scan history depth
  scanFreqDays: 14,           // Scan recurrence
  richActivityTimeline: 0,    // 0|1500|3000|4500|6000|7500
  activityPattern: {          // v3.0: realistic time-of-day patterns
    enabled: false,
    workStart: 9,
    workEnd: 17,
    lunchDip: true,
    nightActivity: false,
    weekendActivity: false
  }
}
```

---

## Industry Verticals (9 total)

| Key | Label | Domain | Taxonomies |
|---|---|---|---|
| `generic` | Generic (ACME Corp) | acme.local | (default) |
| `healthcare` | Healthcare / Hospital | stjoseph.health | HIPAA, PHI, PII |
| `finance` | Financial Services / Banking | wellstrust.bank | SOX, PCI DSS, PII |
| `manufacturing` | Manufacturing / Industrial | (industrial) | ITAR, IP, Trade Secrets |
| `engineering` | Engineering / Tech | (saas) | IP, Customer Data, Source Code |
| `federal` | Federal / Government | (gov) | FedRAMP, FOIA, Classified |
| `education` | Education / University | state.edu | FERPA, Research Data, PII |
| `retail` | **Retail / E-Commerce** | trendmart.com | PCI DSS, PII, Customer Data, GDPR |
| `energy` | **Energy / Utilities** | pacificpower.com | NERC CIP, Critical Infrastructure, PII |

Each vertical defines: `domain`, `spoTenant`, `departments[]`, `fsShares[]`, `spoSites[]`, `onedriveUsers[]`, `taxonomies[]`, `fileNamePatterns[]`.

---

## Demo Profiles (4 sizes)

| Profile | Users | Groups | Admin | Entra Cloud | Guests | SP | Shares | Files/Share | SPO Sites | Docs/Site | Long Inject |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Small Business | 50 | 12 | 5 | 30 | 10 | 5 | 2 | 300 | 1 | 200 | — |
| Mid Market | 1,000 | 50 | 15 | 200 | 50 | 30 | 4 | 1,000 | 3 | 700 | — |
| Upper Mid-Market | 3,000 | 120 | 40 | 600 | 150 | 80 | 6 | 1,500 | 5 | 1,200 | ⚠ |
| Enterprise | 5,000 | 200 | 75 | 1,000 | 300 | 150 | 8 | 2,000 | 8 | 1,500 | ⚠ |

Profiles with `longInject: true` show a SLOW INJECT badge + warning about 10–30 min injection times.

---

## Approach & Patterns

- **Chrome MCP-first discovery:** investigate the live lab via Chrome MCP before writing code. "Do the investigation first, then code." Iterative validation against the live lab beats speculative implementation.
- **Fetch interceptor for undocumented API payloads:** `window.__origFetch = window.fetch; window.fetch = function(...){...}` — reinstall after page navigations.
- **Chrome MCP JS execution:** requires async IIFEs `(async () => { ... })()`. Bare top-level `await` causes errors. For multi-step reads, use `.then()` chaining with `window._varName` storage.
- **Communication style:** TL;DR first, structured tables and bullets, professional tone with light humor, zero filler. Report observed behavior with screenshots and expect diagnosis + fix without extensive back-and-forth.
- **Output preferences:** Production-quality code only (never pseudocode), full error handling, clear next-step sequencing.

---

## Active Constraints (Do Not Break)

- **DO NOT** break v2.7.x ClickHouse functionality (additive changes only for v2.8.0+)
- **DO NOT** introduce build tooling — keep the zero-dependency single HTML model
- **DO NOT** inject real credentials, even in demo placeholders. Use obvious `DEMO/PLACEHOLDER` tokens
- **DO NOT** set scan `cron_enabled: true` — would trigger real scans against fake hosts
- **DO NOT** speculate when Chrome MCP can verify against the live lab
- **DO NOT** make the inline `<style>` block multi-line — breaks `head -12` build step

---

## Tools & Resources

- **Chrome MCP** (`Claude in Chrome`): LAB Browser, deviceId `040280ae-ff39-4f64-95dd-fb2da4e3807a`, consistent active tab
- **Metabase API:** primary injection path. Database ID `2` for ClickHouse. Session via `POST /metabase/api/session` with `{username: 'api@metabase.local', password: ...}`. Auth via `X-Metabase-Session` header.
- **ClickHouse:** `access-analyzer` namespace, accessed via Metabase API
- **Postgres:** `postgres-0` pod in `access-analyzer` namespace, database `access_analyzer`, user `postgres`
- **k3s / kubectl / Traefik:** AA26 server infrastructure; demo-manager Deployment lives in `default` namespace
- **Metabase report card IDs** (key ones): 301, 206, 360, 345, 407, 375, 408, 346; AD Dashboard is dashboard 12 (`sVtIMhPM7uLKSocrC30jl`)
