# AA26 Demo Data Manager — Changelog

## v3.0.0 (current) — Major Release

This release closes the gap between "synthetic-looking demo" and "production-feel demo." The biggest themes are: realistic activity patterns, multi-execution history, scale presets that pair with industry verticals, and a hardened k3s deployment story.

### New Features

#### Industry Verticals (9 total — added 2)
- **🛍️ Retail / E-Commerce (TRENDMART)** — domain `trendmart.com`. Departments cover Store Operations (N/S/E/W regions), Merchandising, E-Commerce, Supply Chain, Loss Prevention, Marketing, Customer Service, IT/POS Systems, PCI Compliance. FS shares: Customer_Data, POS_Logs, PCI_Audit, Loyalty_Program. SPO sites: TrendMart HQ, Store Operations, E-Commerce Hub, PCI Compliance. Taxonomies: PCI DSS, PII, Customer Data, GDPR.
- **⚡ Energy / Utilities (PACIFICPOWER)** — domain `pacificpower.com`. Departments cover Generation (Coal/Nuclear/Hydro/Renewables), Transmission, Distribution, Operations Center (SCADA/Dispatch), Field Services, Regulatory & Compliance (NERC CIP/FERC), IT/Cybersecurity (OT vs IT split), Safety & Environmental. FS shares: SCADA_Records, NERC_CIP, Grid_Operations, Engineering_Drawings. Taxonomies: NERC CIP, PII, Critical Infrastructure, Customer Data.

#### Demo Profile Templates
Moved from Connection tab to Organization tab. Works alongside Industry Vertical (Industry sets the *flavor*, Profile sets the *scale*).

| Profile | Users | Shares | SPO Sites | Inject Time | Badge |
|---|---|---|---|---|---|
| 🏢 Small Business | 50 | 2 | 1 | <1 min | — |
| 🏬 Mid Market | 1,000 | 4 | 3 | ~3 min | — |
| 🏛️ Upper Mid-Market | 3,000 | 6 | 5 | 10–20 min | ⚠ SLOW INJECT |
| 🏰 Enterprise | 5,000 | 8 | 8 | 20–30+ min | ⚠ SLOW INJECT |

Each profile now also scales `cfg.entra.cloudOnly`, `cfg.entra.guests`, `cfg.entra.servicePrincipals`, and `cfg.ad.adminAccounts` proportionally (fixed bug where Entra counts didn't follow profile selection).

#### Multi-Execution History per Scan
Phase 5 SQL now generates **2-7 historical execution clones per scan** instead of one. The API-created execution becomes "today" (1-3 days ago); 2-7 historical clones are INSERTed at `scanFreqDays` intervals going back through `historyMonths`. Object counts use gradual growth (~5% smaller per period older, with ±10% noise, floored at 50% of latest).

This populates the Scan Executions page with realistic trend curves instead of single points. Verified against the live AA26 schema (14 columns: id, scanId, scanType, sourceId, status, totalObjects, completedObjects, errorDetails, completedAt, createdAt, updatedAt, parentExecutionId, postProcessingKey, startedAt).

#### Activity Patterns by Time
New section in the Organization tab below Rich Activity Timeline. Makes rich-timeline events follow realistic business-hour patterns instead of uniform 24/7 distribution.

Controls:
- **Master toggle:** enable/disable patterns
- **Work Day Start / End** (0-23 / 1-24): customize business hours
- **🥗 Lunch Dip:** 50% chance to push events away from the noon hour
- **🌙 Evenings/Nights:** ~15% of events on off-hours (service accounts, on-call); off = strictly work hours
- **📅 Weekends:** sparse Sat/Sun events; off = no weekend events

Weight distribution when enabled: 25% early morning, 30% mid-morning peak, 30% afternoon peak, 15% late. Applied to both `netwrix_activity_monitor_json` (FS) and `netwrix_activity_monitor_spo` (SPO).

#### Web-Worker-Lite (cooperative yielding)
Internal yields added inside the three heaviest loops so the UI stays responsive at Enterprise scale (no more "Page Unresponsive" warnings):

| Loop | Yield Frequency |
|---|---|
| AD user generation | Every 500 users |
| CIFS file generation | Every 200 files |
| SPO doc generation | Every 150 docs |
| v2 cifs entity generation | Every 200 files |

Each yield emits a progress message like `"  Shared_Drive: 800/2000 files..."` so the user sees forward motion. **This is NOT a true Web Worker** — see CHANGELOG-FutureWork.md or AA26-DemoDataManager-Status.md for the technical reasoning and a roadmap if true Web Workers are needed later.

### UI/UX Enhancements

#### Global Step Navigation
The top "Jump to" bar now appears on **every page**, not just Generate. Six pill-shaped buttons (0. Connection / 1. Organization / 2. Identity / 3. Data Sources / 4. Classification / 5. Generate). Current step has a purple ring + accent background. Clicking navigates instantly.

#### Active Operation Banner
A sticky banner now appears at the top of every page during generation or injection. Red pulsing during injection, purple during generation. Shows the latest log line, plus a Stop button (during inject) and a "Go to Step 5 →" navigation button. Solves the "is anything happening?" confusion when the user accidentally tabs away mid-injection.

#### Animated Step Transitions
CSS keyframes added: `fadeInUp` (300ms on step switch), `slideIn` (250ms for toast entrance), `fadeIn` for banner appearance. Buttons have 150ms transition on all properties (hover, focus, active).

#### Modal Wipe Confirmations
Both ClickHouse wipe and AA26 Config wipe now use the Modal component with structured warning lists, X close button, and a proper backdrop. Replaces inline `setWipeConfirm(true)` confirmation that crowded the page.

#### Tooltips (16 HelpIcons)
Added next to: Industry Vertical heading, Demo Profile heading, Organization Name, Domain FQDN, Entra Tenant ID, SID Base, History Depth, Scan Frequency, Stale Users %, PW Never Expires %, Old Passwords %, Empty Groups %, Synced from AD %, Cloud-Only Users, Service Principals, MFA Not Enforced %, Stale Guests %, Overpriv Apps %, Preserve scan pipeline toggle, Activity Pattern enable, all 4 Activity Pattern controls.

#### Toast Notifications
Replaced inline status messages with sliding bottom-right toasts. Used for: profile applied, config exported, config imported, health check passed/failed, wipe complete, etc.

#### Connection Tab Reorder
- 💾 **Config Presets** moved to TOP (export/import full JSON config; strips credentials on export)
- 🩺 **Connection Health Check** moved to BOTTOM (5 checks: same-origin, Metabase API, AA26 REST API, ClickHouse via Metabase, kubectl note)

#### Stats Dashboard
4-card summary on Step 3 (Inject) showing pre-flight counts: AD entries, FS entries, SPO entries, total rows. Helps users sanity-check before injecting.

#### Industry Vertical + Demo Profile Integration
Industry Vertical now has a help icon explaining it sets the *flavor* (departments, file names, taxonomies). Demo Profile has a help icon explaining it sets the *scale* (user/share/site counts). Both work together — pick Industry first, then Profile.

#### Generate Page Restructure
- Removed duplicate sub-step jump bar (was redundant with global jump nav)
- Kept Expand All / Collapse All buttons
- Phase 5 description now mentions multi-execution history

### Infrastructure

#### Installer Script (`install-demo-manager.sh`)
264-line bash script for AA26 server deployment. Subcommands:
- `install` — first-time install (creates ConfigMap + applies manifest)
- `update` — update HTML only (ConfigMap replace + rollout restart)
- `uninstall` — clean removal
- `status` — show current state (version on disk, configmap, pod)
- (no arg) — auto-detect install vs update

Handles all the deployment gotchas: Traefik CRD version detection (auto-rewrites `traefik.io` ↔ `traefik.containo.us`), `kubectl replace` instead of `apply` (avoids the 262KB annotation limit), explicit rollout restart, 60-second pod readiness wait. Colorized output: green ✓ / red ✗ / yellow !.

#### Step 6/7 Deployment Instructions
Updated to reflect actual workflow:
```bash
cd ~/Downloads                                # On workstation
scp demo-data-manager.html sysadmin@appaa:demo-data-manager/   # With trailing slash
ssh sysadmin@appaa
cd ~/demo-data-manager
./install-demo-manager.sh
```

### Bug Fixes

- **Entra not matching Demo Profile** — DEMO_PROFILES now scales `cfg.entra.cloudOnly`, `guests`, `servicePrincipals`, and `cfg.ad.adminAccounts` proportionally
- **Duplicate version badges** — Removed inline `<Badge>v3.0.0</Badge>` from Industry Vertical card, Demo Profile card, AA26 Config card, and AA26 API Authentication. Version appears only in the top header
- **Duplicate jump-nav on Step 5** — Removed local sub-step bar from StepGenerate; only the global jump nav remains
- **SCP path created stray file** — Documented why `scp file.html user@host:foo` (no trailing slash) creates a file *named* `foo` if the directory doesn't exist. Step 6/7 instructions and installer script now defend against this

### Schema Validations (Verified Against Live Lab)
- `scan_executions` table accepts INSERTs with: `id, scan_id, scan_type, source_id, status, started_at, completed_at, created_at, updated_at, total_objects, completed_objects` (nullable columns omitted; the `errorDetails`, `parentExecutionId`, `postProcessingKey` columns get default values)
- Pre-existing v2.8.x findings preserved (covered in Status doc)

---

## Earlier History (Summary — see Status doc for details)

### v2.8.5
- AA26 Configuration orchestrator (5 phases: service accounts → sources → source-group linkage via Postgres → scans → scan executions)
- Dual-mode wipe (Demo Only / Full Reset)
- Generate page restructured into Steps 0-5
- Source-to-source-group linkage via direct Postgres UPDATE (REST API doesn't expose this)
- Post-Setup SQL command generator

### v2.8.0 → v2.8.4
- AA26 REST API integration (verified `_dspm_session` cookie auth, not `_session_id`)
- Service account POST format documented (3 shapes by type: username_password / client_id_secret / client_id_certificate)
- 7 source type UUIDs catalogued (including hidden `localgroups` type)
- Scan executions state machine: pending → running → completed (strict)
- Found that `total_objects: 0` via API is server-controlled (cannot be set via API; only via SQL UPDATE)
- Discovered `sync` scan type is undocumented but functional

### v2.7.x
- ClickHouse injection via Metabase API
- Scan timeline generation (8 scans over 3 months by default)
- Activity Timeline scaling (None → 7,500 events)
- 5-phase generation orchestrator with progress
- Rich Activity Timeline with burst weeks for trend chart realism
