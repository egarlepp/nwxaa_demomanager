# AA26 Demo Data Manager

**Self-contained single-file React app for generating realistic synthetic demo data in Netwrix Access Analyzer (AA26).** Built for Solutions Engineers to spin up compelling demos in 5-15 minutes without needing real data sources or customer infrastructure.

**Current version:** v3.0.0

---

## Quick Links

| Doc | When to Read |
|---|---|
| **[QuickStart.md](AA26-DemoDataManager-QuickStart.md)** | First-time SE running a demo |
| **[Deployment.md](AA26-DemoDataManager-Deployment.md)** | Installing or updating on the AA26 server |
| **[Status.md](AA26-DemoDataManager-Status.md)** | Architecture, gotchas, master reference |
| **[CHANGELOG.md](AA26-DemoDataManager-CHANGELOG.md)** | What changed in each release |
| **[FutureWork.md](AA26-DemoDataManager-FutureWork.md)** | Deferred features, roadmap, technical debt |
| **[NewChat-Handoff.md](AA26-DemoDataManager-NewChat-Handoff.md)** | Onboarding for the next dev session |

---

## What It Does

Generates and injects ~50,000+ rows of realistic AA26 data across three layers:

1. **ClickHouse** — File system, SharePoint, Active Directory, sensitive data findings, activity events
2. **PostgreSQL** — Service accounts, sources, source groups, scans, scan executions
3. **Embedded Metabase** — Powers AA26 dashboards on top of ClickHouse

The result: a complete AA26 demo environment that looks like it's been running in production for months.

---

## Features at a Glance

- **9 Industry Verticals** — Generic, Healthcare, Financial, Manufacturing, Engineering, Federal, Education, Retail, Energy
- **4 Demo Profiles** — Small Business (50 users) → Enterprise (5,000 users)
- **Multi-execution history per scan** — 2-7 historical executions for realistic trend charts
- **Activity Patterns by Time** — Business-hour curves with lunch dip, evenings, weekends toggles
- **5-Phase Configuration Orchestrator** — Service accounts → Sources → Source groups → Scans → Executions
- **Dual-mode wipe** — Demo Only (preserves scan pipeline) or Full Reset
- **Zero build dependencies** — Single HTML file, no webpack/vite/etc
- **Same-origin auto-auth** — When deployed on AA26 server, browser cookie handles everything
- **Web-Worker-Lite** — UI stays responsive at Enterprise scale (5,000 users)

---

## 60-Second Deploy

```bash
# On your workstation
cd ~/Downloads
ssh sysadmin@appaa "mkdir -p ~/demo-data-manager"
scp demo-data-manager.html demo-manager.yaml install-demo-manager.sh \
    sysadmin@appaa:~/demo-data-manager/

# On AA26 server
ssh sysadmin@appaa
cd ~/demo-data-manager
chmod +x install-demo-manager.sh
./install-demo-manager.sh

# Open: https://<aa26-host>/demo-manager/
```

For updates: `./install-demo-manager.sh update` after SCP'ing the new HTML.

---

## Architecture

```
Browser (SE user)
    │
    │  https://aa26-host/demo-manager/  (same origin)
    ▼
┌───────────────────────────────────────────┐
│  Demo Data Manager (this app)             │
│  - Generate data in browser memory        │
│  - Inject to ClickHouse via Metabase API  │
│  - Configure AA26 via REST API            │
│  - Generate Post-Setup SQL for kubectl    │
└───────────────────────────────────────────┘
    │              │              │
    ▼              ▼              ▼
ClickHouse    AA26 REST       PostgreSQL
(analytics)   (app config)    (via kubectl)
```

---

## Development Workflow

1. Edit `aa26-demo-data-manager-v2.jsx` (single source of truth, ~5,000 lines)
2. Validate JSX: `node -e "require('@babel/parser').parse(require('fs').readFileSync('aa26-demo-data-manager-v2.jsx','utf8'),{sourceType:'module',plugins:['jsx']})"`
3. Build HTML: `head -12 demo-data-manager.html > new.html && echo 'const {useState, useCallback, useEffect} = React;' >> new.html && sed 's/^import .*;//;s/^export default function App/function App/' aa26-demo-data-manager-v2.jsx >> new.html && echo 'ReactDOM.createRoot(document.getElementById("root")).render(<App/>);' >> new.html && echo '</script></body></html>' >> new.html && mv new.html demo-data-manager.html`
4. Deploy: `scp demo-data-manager.html sysadmin@appaa:~/demo-data-manager/` + `./install-demo-manager.sh update`
5. Hard-refresh browser (Ctrl+Shift+R)

**Do not introduce webpack/vite/etc.** The `sed` build is intentional — zero dependencies, no build environment required.

---

## License

Internal Netwrix tool. Not for public distribution.

---

## Credits

Built by: Eric (Senior Director, Solutions Engineering) + Claude (Anthropic)
Inspired by: The reality that scheduling demos with real customer data is a nightmare
