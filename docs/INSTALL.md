# Install Guide

Everything needed to get the Demo Data Manager running on a **brand-new AA server** that's never had it installed before — including the access hurdles that actually came up doing this for real, not just the happy path.


---

## What you need before starting

| Item | Notes |
|---|---|
| SSH access to the AA server | As a user with sudo rights (examples below use `<user>`) |
| The three deployment files | `demo-data-manager.html`, `demo-manager.yaml`, `install-demo-manager.sh` — all in the root of this repository (clone it, or download a release) |
| ~15 minutes | Most of it is waiting on `scp` and pod readiness |

---

## Step 1 — Confirm kubectl actually works

SSH in and try:

```bash
ssh <user>@<server>
kubectl get nodes
```

**If that just works** (returns a node, `Ready`), skip to Step 2.

**If you get `permission denied` reading `/etc/rancher/k3s/...` or `kubectl can't connect to cluster`, followed by errors about `dial tcp 127.0.0.1:8080: connect: connection refused`** — this is the single most common snag on a fresh box. It means kubectl fell back to a bogus default because it couldn't read the real kubeconfig. Fix it by giving yourself a personal copy (works regardless of whether the `dspm` group grant was ever applied to this particular server):

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -u) ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
```

Then confirm:

```bash
kubectl get nodes
```

You should see one node, `Ready`. (You may also see harmless `WARN open /etc/rancher/k3s/config.yaml.d: permission denied` lines — ignore those, they're an optional drop-in directory that doesn't apply here.)

---

## Step 2 — Copy the files up

From your workstation:

```bash
ssh <user>@<server> "mkdir -p ~/demo-data-manager"
scp demo-data-manager.html demo-manager.yaml install-demo-manager.sh \
    <user>@<server>:~/demo-data-manager/
```

---

## Step 3 — Run the installer

```bash
ssh <user>@<server>
cd ~/demo-data-manager
chmod +x install-demo-manager.sh
./install-demo-manager.sh
```

With no existing deployment, it auto-detects this is a first-time install and runs through:

1. Preflight checks (kubectl reachable, Traefik CRD version — auto-adjusts if this cluster runs the legacy `traefik.containo.us` API instead of `traefik.io`)
2. Creates the `demo-manager-html` ConfigMap from the HTML
3. Applies the Deployment + Service + Middleware + IngressRoute manifest
4. Waits for the pod to become ready, then prints the access URL

**Verify:**

```bash
./install-demo-manager.sh status
```

Expect something like:

```
[✓] HTML file: ~/demo-data-manager/demo-data-manager.html (vX.X.X)
[✓] Manifest: ~/demo-data-manager/demo-manager.yaml
[✓] ConfigMap: demo-manager-html exists in default
[✓] Deployment: demo-manager (pod: Running)
[i] Access URL: https://<server>/demo-manager/
```

---

## Step 4 — First-time setup in the browser

Open `https://<server>/demo-manager/` and hard-refresh (`Ctrl+Shift+R`) to bypass any stale cache.

### 4a. Connect to Metabase

On the Connection tab, click **Connect**. This uses your existing AA session (same-origin) — no separate Metabase login. On success you'll see the connected database name and a pattern-group/pattern count.

### 4b. Grant DB permissions (one-time per environment — two separate privilege sets)

**This step is easy to miss and will silently block data injection and report population if skipped.** A fresh AA install's Metabase-connected ClickHouse user is read-only by default, and there are **two distinct privilege gaps**, not one:

| Privilege set | What it unlocks | Scope |
|---|---|---|
| `INSERT, TRUNCATE, ALTER DELETE, ALTER UPDATE` | Data injection, wipe, selective removal, rehydration | `access_analyzer.*` |
| `SYSTEM RELOAD DICTIONARY, SYSTEM REFRESH VIEW` | Dictionaries and materialized views actually refreshing after inject — without this, Access/Content/Nested-Shares reports can show stale or empty data even though the injection itself succeeded with 0 errors | `*.*` |

Click **⚡ Grant DB Permissions** (Connection tab, appears once Connect succeeds) — as of v3.2.4 it attempts **both** in one click. If it reports full success, you're done.

**If it fails on either (or both)** — self-granting the `*.*`-scoped SYSTEM privileges is blocked in some environments even when the narrower `access_analyzer.*` grant isn't — run this on the AA server instead:

```bash
sudo kubectl exec -it -n access-analyzer clickhouse-0 -- clickhouse-client --multiquery --query "GRANT INSERT, TRUNCATE, ALTER DELETE, ALTER UPDATE ON access_analyzer.* TO access_analyzer_metabase; GRANT SYSTEM RELOAD DICTIONARY, SYSTEM REFRESH VIEW ON *.* TO access_analyzer_metabase;"
```

**⚠ If you already ran an older version of this command** (from before this doc's v3.2.4 update — just the `INSERT, TRUNCATE, ALTER DELETE, ALTER UPDATE` line, no `SYSTEM RELOAD DICTIONARY`/`SYSTEM REFRESH VIEW`), **run the combined command above again.** GRANT statements in ClickHouse are additive and idempotent — re-running it is completely safe, it just adds the two SYSTEM privileges you're missing without duplicating or undoing anything already granted.

No need to reconnect afterward — just proceed.

### 4c. Detect AA session

On the same Connection tab, click **Detect Session** (AA API Authentication card). This confirms the REST API side (Service Accounts / Sources / Scans) and, since v3.2.0, also discovers the real Sensitive Data Pattern catalog from this instance.

Both cards should show green before moving on.

---

## Step 5 — Generate a demo

Walk the remaining tabs (Organization → Identity → Data Sources → Classification), then on Generate:

1. **Generate Demo Data** → **Fresh Install** (or **Inject**) — populates ClickHouse
2. **Configure AA** — populates Service Accounts, Sources, Scans via the REST API

---

## Updating later (not a fresh install)

Once installed, every future version bump is just:

```bash
scp demo-data-manager.html <user>@<server>:~/demo-data-manager/
ssh <user>@<server> "cd ~/demo-data-manager && ./install-demo-manager.sh"
```

The installer auto-detects the existing deployment and takes the update path (ConfigMap replace + pod restart) instead of reinstalling from scratch. Hard-refresh the browser afterward.

---

## Troubleshooting quick reference

| Symptom | Cause | Fix |
|---|---|---|
| `kubectl can't connect`, `localhost:8080 connection refused` | kubectl fell back to a bad default because it couldn't read the real kubeconfig | Step 1's personal `~/.kube/config` copy |
| `ls: cannot access '/etc/rancher/k3s/k3s.yaml': Permission denied` | Same root cause as above | Same fix — `sudo cp` it out first |
| `No Traefik CRDs found` during preflight | This cluster's ingress controller isn't Traefik | Run `kubectl api-resources \| grep -i ingress` and share the output — the manifest needs adjusting |
| `Code: 497 ... Not enough privileges` on every table during inject | The DML GRANT (Step 4b, first line) hasn't been run yet | Run the GRANT command in Step 4b |
| Inject reports **0 errors**, but Access/Content/Nested-Shares reports show stale or empty data; log shows `SYSTEM RELOAD DICTIONARY` or `SYSTEM VIEWS` `Code: 497` errors during the post-inject dictionary/MV-refresh phase | The SYSTEM-level GRANT (Step 4b, second line) hasn't been run — this is a *separate* privilege gap from the one above, easy to miss since injection itself already succeeded | Run the full combined GRANT command in Step 4b (safe to re-run even if you already ran the older, DML-only version) |
| Two Metabase model cards report "needs a dashboard filter to run" after a wipe | Expected, cosmetic — those two cards require a dashboard parameter the generic cache-bust can't supply | No action needed; refresh those dashboards manually if you want their cache busted too |
| A **Full** config wipe deleted a service account/source you created by hand | Full wipe mode deletes *everything* in Configuration, not just demo-manager-created items | Working as designed — use it deliberately, not casually |

---

## Files reference

| File | Purpose |
|---|---|
| `demo-data-manager.html` | The built app itself — what actually gets served |
| `demo-manager.yaml` | k3s manifest (Deployment + Service + Middleware + IngressRoute) |
| `install-demo-manager.sh` | Installer/updater — handles both first-time install and every future update |
