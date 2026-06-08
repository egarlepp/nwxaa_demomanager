# AA26 Demo Data Manager — Future Work & Roadmap

**This doc is written for future-me.** When you pick this project up again, read this to understand what was deferred, why, and how to approach it.

---

## The Big One: True Web Workers (Deferred)

### What "Web-Worker-Lite" Actually Does (Today)
v3.0 added internal `await tick()` yields inside the heaviest loops:
- AD users: every 500 iterations
- CIFS files: every 200 iterations
- SPO docs: every 150 iterations
- v2 cifs entities: every 200 iterations

This is **cooperative yielding on the main thread** — `tick()` is `() => new Promise(r => setTimeout(r, 10))`. The 10ms timeout pushes the next chunk of work to the end of the event loop, giving React time to render and the user time to interact. It solves the "Page Unresponsive" symptom without actually moving work off the main thread.

**Result:** UI stays responsive even at Enterprise scale (5,000 users). Total generation time is roughly the same as before (maybe slightly slower due to the yield overhead).

### Why True Web Workers Were Deferred
A real Web Worker would:
1. Run all generation on a separate browser thread
2. Free the main thread entirely
3. Allow REAL parallelism if combined with multiple workers

But for a single-file HTML app (no bundler, no separate worker.js file), implementing this requires:

1. **Extract ALL generation code into a self-contained string** (~1,500 lines including constants like `VERTICAL_TEMPLATES`, `FILE_EXTS`, `ACTIVITY_TYPES`, `FIRST_NAMES`, `LAST_NAMES`, plus helpers `pick`, `esc`, `fmt`, `uuid`, `activityDate`, `pickActivityTime`, plus the entire `generateDemoDataAsync` function and every sub-function it calls).
2. **Bundle it via Blob URL:**
   ```javascript
   const workerCode = `
     // Inlined constants as JSON-stringified objects
     const VERTICAL_TEMPLATES = ${JSON.stringify(VERTICAL_TEMPLATES)};
     const FILE_EXTS = ${JSON.stringify(FILE_EXTS)};
     // ... ~10 more constants
     // Inlined helpers via .toString()
     ${pick.toString()}
     ${esc.toString()}
     // ... ~6 more helpers
     // The generate function and all its sub-functions
     ${generateDemoDataAsync.toString()}
     // Worker message handler
     self.onmessage = function(e) {
       const { cfg } = e.data;
       generateDemoDataAsync(cfg, m => self.postMessage({type:'progress',msg:m}), () => Promise.resolve())
         .then(r => self.postMessage({type:'complete', result: r}))
         .catch(err => self.postMessage({type:'error', error: err.message}));
     };
   `;
   const blob = new Blob([workerCode], {type: 'application/javascript'});
   const worker = new Worker(URL.createObjectURL(blob));
   ```
3. **Handle serialization carefully:**
   - The result is large (sometimes 100K+ rows in JSON). `postMessage` uses structured cloning which is efficient but adds latency at scale.
   - The `cfg` object passes fine (plain JSON).
4. **Refactor `handleGenerate`** in App to use the worker via postMessage instead of direct function call.
5. **Test edge cases:** worker errors, abort handling (Web Workers don't have a clean abort — must terminate the worker), browser compatibility.

### Estimated Effort
- Code: 4-6 hours
- Testing: 2-3 hours
- Risk: Medium — subtle serialization bugs and the main risk is that ANY closure captured in `generateDemoDataAsync` that isn't explicitly serialized breaks the worker

### When to Actually Do This
**Don't bother unless:**
- Generation time becomes a bottleneck (currently it's not — injection is the slow part)
- You need to run multiple generations in parallel
- Users complain about typing lag during generation (they don't — Web-Worker-Lite handles this)

**Definitely do this if:**
- You want to add live progress bars during generation
- You want to allow the user to keep editing config while generation runs
- You're building a multi-tenant version where multiple users generate simultaneously

### Where to Start
1. Add a `WORKER_MODE` toggle in DEFAULT_CONFIG (off by default)
2. Extract `generateDemoDataAsync` and its closure deps into a separate `// === WORKER CODE BLOCK ===` region of the JSX
3. Use a code-block-extraction pattern: write the worker code as a string template within the JSX, referencing the named constants via interpolation
4. Implement the worker setup in a separate `generateViaWorker(cfg)` async function that returns the same shape as the current direct call
5. Branch on `cfg.global.workerMode` in `handleGenerate`

---

## Other Deferred Features (Prioritized)

### High Value, Low Effort

#### Wizard Mode (Onboarding)
**What:** Guided 5-step setup for first-time SEs. Walks through: Connection → pick Industry → pick Profile → review → Generate.

**Why deferred:** Larger UX undertaking than was scoped for v3.0.

**Approach:**
- Add a "Wizard Mode" toggle in the header
- When enabled, hide the global jump-nav and replace step content with a guided walkthrough
- Each step has a "Next →" button that validates inputs before proceeding
- Final step shows a summary and a "Generate & Inject All" mega-button

**Estimated effort:** 6-8 hours.

#### Coverage Report (Pre-Generation Preview)
**What:** After config is set but before Generate, show a card with: "Here's what AA26 pages will have data: AD Dashboard ✓ / FS Access Audit ✓ / SPO Sensitive Data ✓ / Identity Risk Catalog ✓ ...".

**Why valuable:** Sets prospect expectations before injecting. Helps SEs know what to demo.

**Approach:** Static mapping from `cfg` flags to report names. Maintainable as a single lookup table.

**Estimated effort:** 2-3 hours.

#### Auto-Update Banner
**What:** Header detects when a newer version of the HTML exists on the server (via ETag check) and shows a banner: "v3.1.0 available — hard-refresh to update."

**Approach:**
- On page load, fetch `window.location.href` with `cache: 'no-store'` and parse the APP_VERSION
- Compare to the loaded version
- Show banner if different

**Estimated effort:** 1-2 hours.

#### Keyboard Shortcuts
**What:** Ctrl+G = Generate, Ctrl+I = Inject, Esc = Cancel active operation, Ctrl+1-6 = jump to step.

**Approach:** Single `useEffect` with a global keydown listener in App. Show a hint chip in the header.

**Estimated effort:** 2 hours.

### Medium Value

#### Postgres in Metabase
**What:** Add Postgres as a second database in Metabase config. This would let Phase 5 SQL run via the Metabase API instead of requiring a kubectl-exec'd command.

**Why valuable:** Removes the one manual step in the entire workflow. Fully automated end-to-end.

**Why deferred:** Requires modifying the AA26 Metabase config — a separate infrastructure change, not a Demo Manager change.

**Approach:**
- On the AA26 server, add a Metabase database connection to PostgreSQL (Metabase Admin → Databases → Add Database)
- Note the new database ID
- In Demo Manager, replace the Phase 5 kubectl command with a Metabase API call against that database ID

**Estimated effort:** 3-4 hours including AA26 infra change.

#### Read-Only Preview Mode
**What:** "Generate without injecting" — useful for review/approval before actual injection.

**Approach:** After Step 1 Generate, show a tabbed preview of the generated tables (first 50 rows of each) before unlocking the Step 2 Inject button.

**Estimated effort:** 4-5 hours.

#### Loading Skeletons
**What:** Replace blank states during async loads with shimmer placeholders.

**Approach:** Standard skeleton component, applied to async results panels.

**Estimated effort:** 2 hours.

#### Search/Filter on Generated Data
**What:** Once 30+ tables show in Generated Data section, add a search box.

**Approach:** Simple text filter on table names.

**Estimated effort:** 1 hour.

### Lower Priority

#### Audit Log / Undo
**What:** Track every state change with timestamps. Allow undoing the last action.

**Estimated effort:** 8-12 hours. Complex because state is tree-shaped.

#### Multi-Tenant Support
**What:** Manage multiple AA26 deployments from one Demo Manager instance.

**Estimated effort:** Days. Significant UX rework.

#### Demo Connector (Real AA26 Scanner)
**What:** Custom `aa26-connector-cli` scanner that pretends to be a real connector.

**Why:** Most authentic demo data — would actually appear in real AA26 scan history.

**Estimated effort:** Weeks. Significant rebuild.

---

## Known Limitations (Not Bugs)

### Metabase Sensitive Data Activity Report
Has mandatory `BETWEEN {{start_date}} AND {{end_date}}` parameters. Cannot be made parameter-optional from the data side. Users must manually pick dates in the report.

### `total_objects` in scan_executions
The AA26 backend overrides this to 0 on API-created executions. Phase 5 SQL backdates and overrides. This is by design — the backend tracks "actually scanned" objects.

### Cross-Origin Mode Limitations
When the tool runs locally (not on the AA26 server), browser security strips the `_dspm_session` cookie from cross-origin requests. The AA26 Configuration features won't work. The tool gracefully degrades to ClickHouse-only mode and shows a "Limited" badge.

### Real-Time Activity Dashboard
The Activity Dashboard relies on `_latest` MaterializedViews that refresh on a timer. After injection, there's a 30-60s lag before the dashboard reflects new data.

### File Size Limit (k3s ConfigMap)
ConfigMap content can technically be up to ~1 MB but `kubectl apply` fails at ~262 KB due to the annotation size limit. The tool's HTML is currently ~327 KB. The `kubectl replace` workaround handles this. If the HTML ever grows past ~1 MB, switch to a PersistentVolume or download from object storage.

---

## Technical Debt

### `aa26-demo-data-manager-v2.jsx` File Size
At ~5,000 lines, the file is getting unwieldy. Refactor candidates:
1. Move VERTICAL_TEMPLATES to its own const block at top — already done
2. Extract generation phases into separate functions (already done — `generateDemoDataAsync` is the entry point)
3. Consider splitting into multiple JSX files and concatenating in the build — adds complexity
4. Consider TypeScript — would require build tooling

**Recommendation:** Don't refactor for the sake of it. The file works, the build is simple, and splitting brings build complexity.

### `head -12` Build Fragility
The build script captures the first 12 lines of HTML for the head section. If anyone adds/removes a line in the head, the count breaks. Fragile but simple.

**Better:** Use a sentinel line like `<!-- BUILD_HEAD_END -->` and `sed`-extract everything before it. Worth the small refactor.

### Test Coverage
Zero automated tests. All validation is manual via Chrome MCP against the lab.

**Recommendation:** Skip automated tests for this project — the surface is small, the iteration cycle is fast, and Chrome MCP gives us live validation. If the tool ever becomes critical infrastructure, add Playwright tests.

### Lack of Versioning Discipline
APP_VERSION is hand-bumped. No semantic-version validation.

**Recommendation:** Add a CI check that verifies APP_VERSION matches the topmost `## v` heading in CHANGELOG.md. Or just keep being disciplined.

---

## When to Bump Versions

| Change | Bump |
|---|---|
| Bug fix, no behavior change | Patch (3.0.0 → 3.0.1) |
| New optional feature, backward compat | Minor (3.0.0 → 3.1.0) |
| Breaking change to config format | Major (3.0.0 → 4.0.0) |
| New Industry Vertical | Minor |
| New Demo Profile | Minor |
| Schema change to ClickHouse INSERTs | Patch (since data is wiped before re-inject) |
| Schema change to AA26 Config plan | Minor (sources/scans may be incompatible) |

---

## What Future-Me Should NOT Do

- **Don't introduce a build system.** The JSX → HTML via `sed` is intentional. Adding webpack/vite/esbuild adds 90% complexity for 5% benefit.
- **Don't refactor for the sake of refactoring.** The code works. Make changes when there's a specific reason.
- **Don't speculate about API behavior.** Always verify against the live lab via Chrome MCP first.
- **Don't change `cron_enabled: true` for scans.** Will trigger real scans against fake hosts.
- **Don't paste real customer credentials anywhere.** Even in demo placeholders, use obvious DEMO/PLACEHOLDER tokens.
- **Don't assume the AA26 API matches docs.** The docs lied about `_session_id` (it's `_dspm_session`). Verify everything.

---

## Quick Wins for Next Session

If you have an hour and want to deliver value:
1. **Coverage Report** (3 hours) — high SE value, low risk
2. **Keyboard shortcuts** (2 hours) — power-user polish
3. **Auto-update banner** (1-2 hours) — eliminates "am I on the latest version?" confusion

If you have a day:
4. **Wizard Mode** (6-8 hours) — biggest onboarding win

If you have a week:
5. **True Web Workers** (8-12 hours) — only if generation perf becomes a problem
6. **Postgres in Metabase** (4 hours infra + 2 hours code) — eliminates the kubectl step entirely

---

## Lessons Learned (For Future Projects)

### What Worked Well
- **Chrome MCP-first discovery.** Investigating the live lab before writing code caught dozens of API gotchas that would have wasted hours of speculative coding.
- **Single-file HTML deployment.** Zero build dependencies meant SEs could iterate fast and developers didn't need a dev environment.
- **Iterative validation.** Each feature was tested in the lab before moving on. No big-bang releases.
- **Honest disclosure about limitations.** Telling users "this is Web-Worker-lite, not true Web Workers" beats overselling.

### What Was Painful
- **The SCP path discipline issue.** Wasted 30+ minutes debugging because of one missing trailing slash. Now defended against in the installer.
- **The 262 KB annotation limit.** Took multiple attempts to figure out why `kubectl apply` was failing. Now documented.
- **API behavior that differed from docs.** `_dspm_session` vs `_session_id` was the worst offender. Verify everything.

### What To Do Differently Next Time
- **Document deployment workflow on day 1.** Don't wait until the user hits the issue.
- **Build the installer script earlier.** It's a small file but saves hours of manual deployment debugging.
- **Set up a changelog from version 1.** Easier to maintain incrementally than reconstructing later.
