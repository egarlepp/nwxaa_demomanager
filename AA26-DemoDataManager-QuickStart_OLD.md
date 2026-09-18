# AA26 Demo Data Manager — QuickStart

**For Solutions Engineers running their first demo.** Skip to the [5-Minute Quickstart](#5-minute-quickstart) if your AA26 lab already has the tool deployed.

---

## 5-Minute Quickstart (Tool Already Deployed)

1. Open `https://<your-aa26-host>/demo-manager/` in Chrome
2. **Step 0: Connection** — click Connect on the Metabase API form. You should see "Auto Mode (Same-Origin)" green badge.
3. **Step 1: Organization**
   - Pick an **Industry Vertical** (sets the flavor — departments, file names, taxonomies)
   - Pick a **Demo Profile** (sets the scale — user counts, share counts)
   - Adjust History Depth / Scan Frequency if desired
4. **Step 2: Identity** — verify AD + Entra counts look right (auto-populated from profile)
5. **Step 3: Data Sources** — verify share + SPO counts (auto-populated from vertical)
6. **Step 4: Classification** — pick sensitive data taxonomies (auto-populated from vertical)
7. **Step 5: Generate**
   - Click **Step 1: Generate** — produces all the synthetic data in memory
   - Click **Step 2: Inject (Metabase API)** — pushes to ClickHouse
   - Click **Step 4: Run AA26 Config** — creates service accounts, sources, scans via REST API
   - Copy the **Step 5: Post-Setup SQL** command and run it on the AA26 server (one kubectl command)
8. Open the AA26 reports. Everything should be populated.

**Typical timing:**
- Small Business (50 users): ~30 seconds generate, ~1 min inject, ~5 min total
- Mid Market (1,000 users): ~30 seconds generate, ~3 min inject, ~7 min total
- Upper Mid-Market (3,000 users): ~1 min generate, ~10 min inject, ~15 min total
- Enterprise (5,000 users): ~2 min generate, ~20-30 min inject, ~30 min total

---

## Industry + Profile Recipe Examples

| Use case | Industry | Profile | Why |
|---|---|---|---|
| Healthcare prospect, 2-hour demo | Healthcare / Hospital | Mid Market | Realistic hospital data + 1,000 users is enough to show all reports |
| Financial services exec preview | Financial Services / Banking | Upper Mid-Market | SOX/PCI taxonomies + 3,000 users feels "real bank" |
| Quick discovery call | Generic | Small Business | 50 users injects in <1 min — fast iteration |
| Energy / utility RFP | Energy / Utilities | Enterprise | NERC CIP / SCADA themes + max scale impresses |
| Retail / e-commerce prospect | Retail / E-Commerce | Mid Market | PCI DSS + TrendMart theming, manageable scale |

**Industry sets flavor. Profile sets scale. Pick Industry FIRST, then Profile.**

---

## The 5-Phase Generate Pipeline (Step 5)

```
Step 0: Wipe (optional)          ← Run before re-injecting to avoid duplicates
   ↓
Step 1: Generate                  ← Build all data in browser memory (~30s-2min)
   ↓
Step 2: Inject (Metabase API)     ← Push ClickHouse INSERTs (~1-30 min)
   ↓
Step 3: Stats Dashboard           ← Pre-flight counts before AA26 Config
   ↓
Step 4: AA26 Configuration        ← 5-phase API orchestrator:
   ↓                                 - service accounts
                                     - sources
                                     - source group linkage (via Postgres, not API)
                                     - scans
                                     - scan executions
Step 5: Post-Setup SQL            ← Copy/paste one kubectl command to:
                                     - link sources to source groups
                                     - backdate the latest execution
                                     - insert 2-7 historical execution clones per scan
                                     (Multi-execution history makes trend charts realistic)
```

---

## Activity Patterns by Time (v3.0)

If you want the Activity Dashboard to show realistic business-hour curves instead of flat 24/7 distribution, enable this in the **Organization tab → Activity Patterns by Time** section (collapsible, below Rich Activity Timeline).

| Setting | What it does |
|---|---|
| Master toggle | Off = uniform 24/7 (legacy behavior). On = patterns apply. |
| Work Day Start/End | Hour range when activity concentrates. Default 9–17. |
| 🥗 Lunch Dip | Reduces events around noon (50% reroll from 12) |
| 🌙 Evenings/Nights | ON = ~15% of events on off-hours (admins, on-call) |
| 📅 Weekend activity | ON = sparse Sat/Sun events. OFF = no weekend events at all |

**Recommended for first time:** Enable patterns + lunch dip + leave evenings/weekends OFF. Most realistic for a standard office org.

---

## Demo Profile Decision Tree

```
Need it injected in <5 min?
  └── YES → Small Business (50 users)
  └── NO  → Need to show realistic scale?
            └── 1k-3k users typical mid-size client → Mid Market or Upper Mid-Market
            └── Enterprise prospect, max scale       → Enterprise
                (note: 20-30 min injection)
```

⚠ **Upper Mid-Market and Enterprise profiles** trigger a SLOW INJECT badge. Plan demos accordingly — don't run these 5 minutes before a customer call.

---

## Common Tasks

### Re-running a demo (wipe + regenerate)
1. **Step 5 → Step 0: Wipe Data** — choose "Demo Only" (preserves scan pipeline) or "Full Reset" (clears everything)
2. The Modal confirms what will be deleted
3. Click confirm → wait for completion → run Generate + Inject + AA26 Config + Post-Setup SQL again

### Exporting / sharing a config
1. **Step 0: Connection → Config Presets** at the top of the page
2. Click **📥 Export Config** — downloads a JSON file (credentials are stripped)
3. Send to a teammate
4. They click **📤 Import Config** to load it

### Running a health check
1. **Step 0: Connection → Connection Health Check** at the bottom of the page
2. Click **🩺 Run Health Check** — runs 5 checks:
   - Same-Origin Deployment
   - Metabase API
   - AA26 REST API
   - ClickHouse via Metabase
   - kubectl Postgres Access (informational)
3. All-green = good to go.

### Updating the tool on the AA26 server
On your workstation, after downloading a new `demo-data-manager.html`:
```bash
cd ~/Downloads
scp demo-data-manager.html sysadmin@appaa:~/demo-data-manager/
ssh sysadmin@appaa
cd ~/demo-data-manager
./install-demo-manager.sh update
```

Hard-refresh your browser (Ctrl+Shift+R) to see the new version.

---

## Where to Look in AA26 After Running

| AA26 Page | Should Show |
|---|---|
| Reports → Identity → Stale Users | ~8% of users (configurable) |
| Reports → Identity → PW Never Expires | ~5% of users (configurable) |
| Reports → File System → Permission Risk | Permissions on files & shares |
| Reports → SharePoint → Sensitive Data | Sensitive findings tagged with taxonomies |
| Reports → SharePoint → Activity | Realistic timeline events (with pattern if enabled) |
| Reports → AD → Risk Catalog | All AD risk categories populated |
| Dashboards → AD Dashboard | Trend lines across scan history |
| Configuration → Service Accounts | 3-5 created |
| Configuration → Sources | 4-8 created (varies by profile) |
| Configuration → Scans | 8-12 scans across types (sync, access_scan, sensitive_data_scan) |
| Configuration → Scan Executions | **2-7 historical executions per scan** showing growth over time |

---

## Troubleshooting

### "Auto Mode disabled — Cross-Origin"
You're accessing the tool from a domain other than the AA26 server. Either:
- Deploy on the AA26 server (recommended — see Deployment doc)
- Manually paste your `_dspm_session` cookie value into the Auth field (limited features)

### "Metabase API session expired"
Click Connect again on the Metabase API form. Sessions last several hours.

### "Page Unresponsive" warning during generation
This was fixed in v3.0 (Web-Worker-lite added internal yields). If you still see it on Enterprise scale, hard-refresh and try again — you may be on an old version.

### Phase 5 Post-Setup SQL says "Not a directory" or path errors
The HTML file may be in the wrong location on the AA26 server. SSH in and run:
```bash
grep "APP_VERSION" ~/demo-data-manager/demo-data-manager.html
ls -la ~/demo-data-manager/
```
The file should be at `~/demo-data-manager/demo-data-manager.html`. See Deployment doc for SCP path discipline.

### Injection takes forever and shows "Page Unresponsive"
Pre-3.0 versions freeze the main thread during large generations. Upgrade to v3.0+ which has cooperative yielding. For Enterprise scale (5,000 users), expect 20-30 min injection even with v3.0.

### Reports show data but Scan Executions page is empty
You skipped the Phase 5 Post-Setup SQL step. It's not optional — it's what populates the Scan Executions page with the multi-execution history.

---

## Pro Tips

1. **Save your favorite configs as JSON presets** — much faster than re-picking Industry + Profile + adjustments every time
2. **The Activity Pattern preview line** at the bottom of that section is your friend — it tells you exactly what will happen in plain English
3. **Run Health Check before a customer call** — catches expired sessions and config drift
4. **The Active Operation Banner** is your friend — if you accidentally tab away during injection, the red sticky banner at the top tells you it's still running
5. **Demo Only wipe** preserves real AA26 scan data — use this if your lab has any real scans you want to keep
