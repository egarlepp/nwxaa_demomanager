# AA26 Demo Data Manager — Handoff for Next Chat

**Last updated:** v3.0.0 release
**State:** Stable. Deployed on lab. All planned v3.0 features shipped.

---

## TL;DR for Next Claude

The Demo Manager is at **v3.0.0** and feature-complete for the v3.0 roadmap. 14 of 15 features delivered (Wizard Mode is the only one deferred — see FutureWork.md). The tool is deployed on the AA26 lab at `https://appaa.cloud.lab/demo-manager/` and is being used by SEs for real demos.

Default starting context for any new conversation:
1. Read **Status.md** for architecture, defaults, and the "never lose these" gotchas
2. Read **FutureWork.md** before suggesting new features (most have been considered already)
3. Use **Chrome MCP LAB Browser** (deviceId `040280ae-ff39-4f64-95dd-fb2da4e3807a`) to validate against the live lab before writing code
4. The source of truth is `aa26-demo-data-manager-v2.jsx`; the deployed artifact is `demo-data-manager.html`
5. **Don't introduce build tooling.** The `sed`-based JSX→HTML build is intentional.

---

## What Changed Since v2.8.5

See **CHANGELOG.md** for the full list. The big themes:

| Theme | What |
|---|---|
| Realism | Multi-execution history per scan + Activity Patterns by Time |
| Onboarding | Demo Profile templates + Industry Vertical integration + Tooltips on key settings |
| UX polish | Global jump nav, animated transitions, Active Operation Banner, Modal wipe confirms, Toast notifications |
| Verticals | Added Retail (TRENDMART/PCI) and Energy (PACIFICPOWER/NERC CIP) |
| Performance | Web-Worker-Lite: internal yields in heavy loops |
| Deployment | Installer script + Step 6/7 instructions corrected for actual server paths |

---

## Current File State

```
/home/claude/ or /mnt/user-data/outputs/ :
├── aa26-demo-data-manager-v2.jsx              # Source (~5,011 lines)
├── demo-data-manager.html                     # Built artifact (~5,027 lines, ~327 KB)
├── demo-manager.yaml                          # k3s manifest
├── install-demo-manager.sh                    # Installer (264 lines)
├── AA26-DemoDataManager-Status.md             # Master reference
├── AA26-DemoDataManager-CHANGELOG.md          # Full change history since v2.8.x
├── AA26-DemoDataManager-QuickStart.md         # SE-facing quick start
├── AA26-DemoDataManager-Deployment.md         # k3s deployment + pitfalls
├── AA26-DemoDataManager-FutureWork.md         # Roadmap + tech debt notes
└── AA26-DemoDataManager-NewChat-Handoff.md    # This doc
```

---

## Deployment State on Lab

- **AA26 Server:** appaa.cloud.lab (k3s)
- **HTML location on server:** `/home/sysadmin/demo-data-manager.html` (note: lives in home, not in a subfolder, due to manual deployment history — installer recommends `~/demo-data-manager/` for new installs)
- **Pod:** `demo-manager` deployment in `default` namespace
- **ConfigMap:** `demo-manager-html` in `default` namespace
- **Ingress:** Traefik IngressRoute at `/demo-manager/`
- **Last deployed version:** v3.0.0

---

## Active Tasks / Open Threads

**None.** v3.0.0 is shipped. Next session is a fresh start unless user has new requirements.

### Likely Next Asks (User Hints from this Session)
1. Implement Wizard Mode (deferred from v3.0)
2. Coverage Report (pre-generation preview of which AA26 pages will populate)
3. Auto-update banner (detect new version on server)
4. Postgres in Metabase (eliminates the kubectl Phase 5 step)

See **FutureWork.md** for effort estimates on each.

---

## Critical "Do Not Forget" Items

These come up every session. Internalize them.

### Tool & Workflow
- **Chrome MCP first.** Always investigate live before coding. The lab is more authoritative than any doc.
- **Fetch interceptor pattern** for capturing undocumented API payloads:
  ```javascript
  window.__origFetch = window.fetch;
  window.fetch = function(...args) {
    if (args[0].includes('/api/')) window.__captured = args[1]?.body;
    return window.__origFetch.apply(this, args);
  };
  ```
- **Async IIFE** for Chrome MCP JS execution: `(async () => { ... })()`. Top-level await fails.
- **Validate JSX parse before HTML rebuild:** `node -e "require('@babel/parser').parse(...)"` catches syntax errors early.
- **str_replace surgically.** Never full rewrites on ~5,000-line files.

### API & Auth
- Cookie name: `_dspm_session` (NOT `_session_id`)
- Service account POST: `client_id` and `tenant_id` go at ROOT, NOT in parameters array
- Sources: simple POST {name, sourceTypeId, serviceAccountId, connectionParameters}
- Source-to-source-group linkage: Postgres UPDATE only — API silently ignores
- Scans: snake_case fields, always `cron_enabled: false`
- Scan execution state: pending → running → completed (strict)
- `total_objects` is server-controlled — set via SQL UPDATE only

### k3s / Deployment
- ConfigMap update: `kubectl replace` not `apply` (262 KB annotation limit)
- Pod restart after ConfigMap update: explicit `kubectl rollout restart`
- SCP target trailing slash matters: `:demo-data-manager/` vs `:demo-data-manager`
- Postgres exec: `kubectl exec -i postgres-0 -n access-analyzer -- psql -U postgres -d access_analyzer` (use `-i` not `-it`)

### Build & Style
- Inline HTML `<style>` must be ONE LINE (build script uses `head -12`)
- The build is `sed`-based — do not introduce webpack/vite/etc.

---

## Style Reminders for User Communication

The user is **Senior Director, Solutions Engineering, Netwrix** — technical, busy, prefers:
- **TL;DR first, structured tables and bullets, professional with light humor, zero fluff**
- Production-ready code with error handling (never pseudocode)
- Identity-Centric / Zero Trust security posture
- Frameworks: 3Ps, VRE, 5As, Brace, TCC, MEDDPICC
- Special commands: `/critic`, `/tldr`, `/roi`, `/ciq`

When in doubt, lean toward concise. Long responses with extensive preamble waste their time.

---

## Approach for Next Session

1. **Read Status.md first.** It has the architecture and gotchas.
2. **Restore workspace** from `/mnt/user-data/outputs/` if `/home/claude/` is empty.
3. **Use Chrome MCP** before assuming anything about API behavior.
4. **Don't reimplement what's already there.** Check the file before adding helpers.
5. **Validate JSX → build HTML → present files** — every cycle.
6. **Honest disclosure** when something is partially implemented (e.g., "this is Web-Worker-lite, not true Web Workers").

---

## Verification Commands (For Next Session Sanity Check)

```bash
# Workspace state
ls -la /home/claude/*.jsx /home/claude/*.html /home/claude/*.md /home/claude/*.sh 2>/dev/null

# Current version
grep APP_VERSION /home/claude/aa26-demo-data-manager-v2.jsx | head -1

# Line count (should be ~5,011)
wc -l /home/claude/aa26-demo-data-manager-v2.jsx

# JSX validates
node -e "require('@babel/parser').parse(require('fs').readFileSync('/home/claude/aa26-demo-data-manager-v2.jsx','utf8'),{sourceType:'module',plugins:['jsx']}); console.log('OK')"

# What's actually deployed on the lab (via Chrome MCP)
# (async () => { const r = await fetch(window.location.href, {cache:'no-store'}); const t = await r.text(); const m = t.match(/APP_VERSION = "([^"]+)"/); return m?m[1]:'NOT FOUND'; })()
```

---

## If The User Says "Restart" or "Fresh Slate"

Don't actually restart. Just say: "Picking up from v3.0.0. What would you like to work on?" and reference QuickStart.md / FutureWork.md as appropriate. The user has invested significant time getting to this state — don't waste it.
