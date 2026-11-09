# Roadmap & Known Limitations

Ideas that have been scoped but not built, plus behaviour that looks like a bug but isn't. Contributions toward any of these are welcome — see [CONTRIBUTING.md](../CONTRIBUTING.md).

---

## Deferred features

### High value, low effort

| Feature | What | Approach | Effort |
|---|---|---|---|
| **Coverage report** | Before Generate, show which AA pages will have data (AD Dashboard ✓, FS Access Audit ✓, SPO Sensitive Data ✓ …). | Static lookup table from `cfg` flags to report names. | 2–3 h |
| **Auto-update banner** | Detect that a newer HTML is deployed and prompt a hard refresh. | On load, `fetch(location.href, {cache:'no-store'})`, parse `APP_VERSION`, compare. | 1–2 h |
| **Keyboard shortcuts** | Ctrl+G Generate, Ctrl+I Inject, Esc cancel, Ctrl+1–6 jump to step. | One global `keydown` listener in `App`; hint chip in the header. | 2 h |
| **Wizard mode** | Guided first-run flow: Connection → Industry → Profile → Review → Generate. | Header toggle that swaps jump-nav for a validated step-by-step flow. | 6–8 h |

### Medium value

| Feature | What | Notes |
|---|---|---|
| **Postgres in Metabase** | Run Phase 5 (post-setup SQL) through the Metabase API instead of a `kubectl exec` script. | Requires adding Postgres as a Metabase database on the AA server — an infrastructure change, not just an app change. Removes the last manual step. |
| **Read-only preview** | Generate without injecting; show the first 50 rows of each table for review. | Gate the Inject button behind the preview. |
| **Search on Generated Data** | Filter box once 30+ tables are listed. | Simple name filter. |
| **Loading skeletons** | Shimmer placeholders during async loads. | Cosmetic. |

### Lower priority

- **Audit log / undo** — state is tree-shaped, so this is 8–12 h.
- **Multi-instance support** — manage several AA deployments from one page. Significant UX rework.

### True Web Workers

Generation already yields to the event loop inside its heaviest loops (AD users every 500 iterations, CIFS files every 200, SPO docs every 150), so the UI stays responsive at Enterprise scale. Moving generation to a real Web Worker would require serialising `generateDemoDataAsync` and every constant/helper it closes over into a Blob-URL worker — any missed closure breaks it silently. Not worth it unless generation (not injection) becomes the bottleneck, or live progress/editing during generation is required.

---

## Known limitations (not bugs)

- **Sensitive Data Activity report** has mandatory `start_date`/`end_date` parameters in Metabase; pick dates manually in the report.
- **`total_objects` on scan executions** is forced to 0 by the AA backend for API-created executions; the Phase 5 script backfills it.
- **Cross-origin mode** — when the page is not served from the AA origin, the browser won't send the AA session cookie, so the AA Configuration features are unavailable and the app runs in ClickHouse-only mode. Deploy same-origin (see [INSTALL.md](INSTALL.md)).
- **Activity dashboards lag 30–60 s** after injection while `_latest` materialized views refresh.
- **SharePoint `normalized_permissions`** (`FixedString(5)`) still uses a placeholder value — no documented letter scheme was found, so the tool does not guess.
- **"Preserve Scan Pipeline" wipe** (the default) intentionally keeps the v2 entity tables, so Shared Links, High Risk ACLs and Open Access keep showing old data until a Full Reset or fresh inject.
- **ConfigMap size** — `kubectl apply` fails above ~262 KB because of the last-applied annotation, so the installer uses `kubectl create … --dry-run | kubectl replace`. ConfigMaps cap at 1 MiB; past that, switch to a volume.

---

## Versioning

| Change | Bump |
|---|---|
| Bug fix, no behaviour change | Patch |
| New optional feature, new vertical or profile | Minor |
| Change to the AA configuration plan (sources/scans) | Minor |
| Breaking change to the saved config / preset format | Major |

`APP_VERSION` in `demo-data-manager.html` and the top entry in [CHANGELOG.md](CHANGELOG.md) should always match — CI checks this.
