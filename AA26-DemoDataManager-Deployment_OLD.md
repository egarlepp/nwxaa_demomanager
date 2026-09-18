# AA26 Demo Data Manager — Deployment Guide

This doc covers deploying the tool on the AA26 server (k3s/Traefik), updating it across versions, and avoiding the deployment pitfalls we hit during development.

---

## Prerequisites

- AA26 server with k3s running (Traefik ingress installed)
- `kubectl` configured on the server
- SSH access to the server as the deploy user (typically `sysadmin`)
- The three deployment artifacts:
  - `demo-data-manager.html` (the built single-file app)
  - `demo-manager.yaml` (k3s manifest)
  - `install-demo-manager.sh` (the installer script)

---

## First-Time Install (Recommended Path)

### On Your Workstation
```bash
# Create the install folder on the server (one-time)
ssh sysadmin@appaa "mkdir -p ~/demo-data-manager"

# Copy all three files into the folder
cd ~/Downloads
scp demo-data-manager.html demo-manager.yaml install-demo-manager.sh \
    sysadmin@appaa:~/demo-data-manager/
```

### On the AA26 Server
```bash
ssh sysadmin@appaa
cd ~/demo-data-manager
chmod +x install-demo-manager.sh
./install-demo-manager.sh
```

The installer auto-detects whether this is a first-time install or an update. On first install it:
1. Runs preflight checks (kubectl, cluster connection, Traefik CRD version)
2. Auto-rewrites the YAML if Traefik uses the legacy `traefik.containo.us` API
3. Creates the `demo-manager-html` ConfigMap from the HTML file
4. Applies the manifest (Deployment + Service + IngressRoute)
5. Waits up to 60s for pod readiness
6. Prints the access URL

### Verify
```bash
./install-demo-manager.sh status
```

Should show:
```
[✓] HTML file: ~/demo-data-manager/demo-data-manager.html (327K, v3.0.0)
[✓] Manifest: ~/demo-data-manager/demo-manager.yaml
[✓] ConfigMap: demo-manager-html exists in default
[✓] Deployment: demo-manager (pod: Running)
[i] Access URL: https://appaa.cloud.lab/demo-manager/
```

---

## Updating to a New Version

### On Your Workstation
```bash
cd ~/Downloads
scp demo-data-manager.html sysadmin@appaa:~/demo-data-manager/
```

### On the AA26 Server
```bash
ssh sysadmin@appaa
cd ~/demo-data-manager
./install-demo-manager.sh update
```

The installer:
1. Reads the new HTML's `APP_VERSION` and the current ConfigMap's version
2. Logs the diff (e.g., `v2.8.5 → v3.0.0`)
3. Replaces the ConfigMap using `kubectl create ... --dry-run | kubectl replace -f -` (the correct pattern — see Pitfall #1 below)
4. Restarts the Deployment with `kubectl rollout restart`
5. Waits for the new pod to be ready

After the install completes, **hard-refresh your browser** (`Ctrl+Shift+R` / `Cmd+Shift+R`) to see the new version in the header.

---

## Manual Commands (If You Need Them)

### Update HTML only (manual ConfigMap replace)
```bash
kubectl create configmap demo-manager-html \
  --from-file=index.html=/home/sysadmin/demo-data-manager/demo-data-manager.html \
  -n default --dry-run=client -o yaml | kubectl replace -f -
kubectl rollout restart deployment/demo-manager -n default
```

### Check the version that's actually being served
```bash
grep "APP_VERSION" ~/demo-data-manager/demo-data-manager.html
kubectl get configmap demo-manager-html -n default -o jsonpath='{.data.index\.html}' | grep "APP_VERSION"
```

### View pod logs
```bash
kubectl logs -l app=demo-manager -n default --tail=50
```

### View pod status / events
```bash
kubectl describe pod -l app=demo-manager -n default
```

### Full uninstall
```bash
cd ~/demo-data-manager
./install-demo-manager.sh uninstall
# Then optionally:
rm -rf ~/demo-data-manager
```

---

## Pitfalls We Hit (And How to Avoid Them)

### Pitfall #1: `kubectl apply` Fails on Large ConfigMaps
**Symptom:** `kubectl apply` returns an error about `last-applied-configuration` annotation exceeding the size limit.

**Cause:** The HTML file is ~327 KB, but Kubernetes annotations have a 262 KB hard limit. `kubectl apply` tries to store the entire manifest as an annotation for diff tracking.

**Fix:** Use the `kubectl create ... --dry-run | kubectl replace` pattern (which is what the installer script does):
```bash
kubectl create configmap demo-manager-html \
  --from-file=index.html=/path/to/html \
  -n default --dry-run=client -o yaml | kubectl replace -f -
```

`kubectl replace` doesn't store the last-applied annotation, sidestepping the limit.

### Pitfall #2: Pod Doesn't Pick Up New ConfigMap
**Symptom:** You updated the ConfigMap but the pod still serves the old HTML.

**Cause:** Kubernetes does NOT automatically restart pods when their mounted ConfigMaps change. The volume mount stays stale.

**Fix:** Explicitly restart:
```bash
kubectl rollout restart deployment/demo-manager -n default
kubectl rollout status deployment/demo-manager -n default
```

### Pitfall #3: SCP Creates a File Named Like a Directory
**Symptom:** You ran `scp file.html user@host:demo-data-manager` (no trailing slash). On the server, instead of a `~/demo-data-manager/` directory containing `file.html`, you now have a *file* named `demo-data-manager` (no extension) with the HTML content.

**Cause:** SCP behavior: if the target ends without a slash AND the target directory doesn't exist, SCP creates a file with that name. Bash users intuitively think of `:demo-data-manager` as "the demo-data-manager folder" but SCP doesn't.

**Fix:** Always use one of these unambiguous patterns:
```bash
# ✅ Trailing slash = "into this directory"
scp file.html user@host:demo-data-manager/

# ✅ Explicit filename
scp file.html user@host:demo-data-manager/file.html

# ❌ Ambiguous — works only if directory exists
scp file.html user@host:demo-data-manager
```

The installer script defends against this by checking that the input file exists at the expected path and printing a clear error if not.

### Pitfall #4: Traefik CRD API Version Mismatch
**Symptom:** `kubectl apply -f demo-manager.yaml` errors out with `no matches for kind "IngressRoute"`.

**Cause:** Different k3s versions ship with different Traefik CRD API versions:
- Newer: `traefik.io/v1alpha1`
- Legacy: `traefik.containo.us/v1alpha1`

**Fix:** The installer auto-detects and rewrites. Manual check:
```bash
kubectl api-resources | grep traefik
```

If you see `traefik.containo.us`, hand-edit `demo-manager.yaml` to use that API version (or just use the installer).

### Pitfall #5: Multi-Line `<style>` Block Breaks Build
**Symptom:** The HTML build script (`sed`-based) produces a broken HTML file.

**Cause:** The build does `head -12 demo-data-manager.html` to capture the head section, expecting exactly 12 lines. If the inline `<style>` block spans multiple lines, the count is off and the React script section gets cut off.

**Fix:** Keep the `<style>` block on a single line. If you need to add CSS, concatenate it onto the existing line. Example:
```html
<style>*{box-sizing:border-box}body{font-family:'Outfit',sans-serif}@keyframes fadeIn{from{opacity:0}to{opacity:1}}/* ...etc... */</style>
```

### Pitfall #6: Same-Origin vs Cross-Origin Auth
**Symptom:** AA26 Configuration features fail with "Browser security blocks cross-origin cookie auth."

**Cause:** When the tool runs on a different origin than AA26 (e.g., `localhost:8080` vs `appaa.cloud.lab`), the browser strips the `_dspm_session` cookie from API requests per the Fetch spec.

**Fix:** Deploy on the AA26 server itself (same-origin). The k3s deployment via Traefik ingress at `/demo-manager/` makes everything same-origin and auth works automatically.

**Workaround for local development:** The tool supports manual cookie pasting in the AA26 API Authentication panel — copy your `_dspm_session` value from DevTools and paste it. Limited features only.

### Pitfall #7: Postgres Access Requires kubectl-exec
**Symptom:** Phase 5 SQL doesn't run automatically.

**Cause:** Metabase is configured for ClickHouse only — there's no Postgres connection in Metabase. The tool generates a kubectl command for the user to run on the server because the browser can't run kubectl.

**Fix:** Copy the Post-Setup SQL command from the tool and paste it into your SSH session on the AA26 server:
```bash
kubectl exec -i postgres-0 -n access-analyzer -- psql -U postgres -d access_analyzer << 'EOSQL'
BEGIN;
... SQL here ...
COMMIT;
EOSQL
```

Use `-i` (interactive) not `-it` (terminal) for piped/heredoc input.

---

## YAML Manifest Reference (`demo-manager.yaml`)

The manifest creates three resources in the `default` namespace:

```yaml
# 1. Deployment — single-replica nginx pod mounting the ConfigMap
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-manager
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-manager
  template:
    metadata:
      labels:
        app: demo-manager
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: demo-manager-html
---
# 2. Service — cluster-internal access
apiVersion: v1
kind: Service
metadata:
  name: demo-manager
  namespace: default
spec:
  selector:
    app: demo-manager
  ports:
  - port: 80
    targetPort: 80
---
# 3. IngressRoute — Traefik routes /demo-manager/ to the Service
apiVersion: traefik.io/v1alpha1   # or traefik.containo.us/v1alpha1 for legacy
kind: IngressRoute
metadata:
  name: demo-manager
  namespace: default
spec:
  entryPoints:
  - websecure
  routes:
  - match: PathPrefix(`/demo-manager`)
    kind: Rule
    services:
    - name: demo-manager
      port: 80
    middlewares:
    - name: demo-manager-stripprefix
  tls: {}
---
# 4. Middleware to strip the /demo-manager prefix before forwarding to nginx
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: demo-manager-stripprefix
  namespace: default
spec:
  stripPrefix:
    prefixes:
    - /demo-manager
```

The IngressRoute uses the existing TLS termination from AA26's main Traefik config — no extra cert handling required.

---

## SCP Workflow Cheat Sheet

| Scenario | Command |
|---|---|
| First time, folder doesn't exist | `ssh sysadmin@appaa "mkdir -p ~/demo-data-manager"` then SCP |
| Copy into existing folder | `scp file.html sysadmin@appaa:~/demo-data-manager/` (trailing slash!) |
| Explicit overwrite | `scp file.html sysadmin@appaa:~/demo-data-manager/file.html` |
| Copy multiple files | `scp file1.html file2.yaml file3.sh sysadmin@appaa:~/demo-data-manager/` |
| Verify after copy | `ssh sysadmin@appaa "ls -la ~/demo-data-manager/"` |
| Check version on disk | `ssh sysadmin@appaa "grep APP_VERSION ~/demo-data-manager/demo-data-manager.html"` |

---

## Pod Lifecycle Reference

### When does the pod restart?
- ConfigMap update **does NOT** auto-restart the pod
- `kubectl rollout restart deployment/demo-manager -n default` triggers a graceful rollout
- Image change in the manifest triggers a rollout
- Node failure / drain triggers a reschedule

### What does the user see during a rollout?
- New pod spins up alongside the old one (rolling update strategy)
- When the new pod is Ready, traffic flips
- Total downtime: typically <2 seconds

### Browser hard-refresh required after update
The user must `Ctrl+Shift+R` (or `Cmd+Shift+R`) — without this, the browser uses the cached HTML. The new version is visible in the header (e.g., "v3.0.0").
