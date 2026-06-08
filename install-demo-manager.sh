#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# AA26 Demo Data Manager — Installer / Updater
# Run on the AA26 server. Handles first-time install OR version updates.
# Usage:
#   ./install-demo-manager.sh                  # interactive (auto-detect)
#   ./install-demo-manager.sh install          # force first-time install
#   ./install-demo-manager.sh update           # force update of HTML only
#   ./install-demo-manager.sh uninstall        # remove everything
#   ./install-demo-manager.sh status           # show current deployment state
# ─────────────────────────────────────────────────────────────────────────────

set -e

# Color helpers
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
log()  { printf "${BLUE}[i]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()  { printf "${RED}[✗]${NC} %s\n" "$*" >&2; }
hdr()  { printf "\n${BOLD}=== %s ===${NC}\n" "$*"; }

# Configuration
INSTALL_DIR="${HOME}/demo-data-manager"
HTML_FILE="${INSTALL_DIR}/demo-data-manager.html"
YAML_FILE="${INSTALL_DIR}/demo-manager.yaml"
NAMESPACE="default"
DEPLOYMENT="demo-manager"
CONFIGMAP="demo-manager-html"

# ─── Preflight checks ────────────────────────────────────────────────────────
preflight() {
  hdr "Preflight Checks"
  if ! command -v kubectl >/dev/null 2>&1; then
    err "kubectl not found. This installer must run on the AA26 server."; exit 1
  fi
  ok "kubectl found: $(kubectl version --client --short 2>/dev/null | head -1)"

  if ! kubectl get nodes >/dev/null 2>&1; then
    err "kubectl can't connect to cluster. Check kubeconfig."; exit 1
  fi
  ok "Cluster reachable: $(kubectl get nodes -o name | wc -l) node(s)"

  # Detect Traefik CRD version
  if kubectl api-resources 2>/dev/null | grep -q "traefik.io"; then
    TRAEFIK_API="traefik.io/v1alpha1"
    ok "Traefik CRD: traefik.io (modern)"
  elif kubectl api-resources 2>/dev/null | grep -q "traefik.containo.us"; then
    TRAEFIK_API="traefik.containo.us/v1alpha1"
    warn "Traefik CRD: traefik.containo.us (legacy) — will rewrite yaml"
  else
    err "No Traefik CRDs found. Is AA26 actually running k3s with Traefik ingress?"; exit 1
  fi
}

# ─── State detection ─────────────────────────────────────────────────────────
detect_state() {
  HAS_HTML=false; HAS_YAML=false; HAS_CONFIGMAP=false; HAS_DEPLOYMENT=false
  [ -f "$HTML_FILE" ] && HAS_HTML=true
  [ -f "$YAML_FILE" ] && HAS_YAML=true
  kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" >/dev/null 2>&1 && HAS_CONFIGMAP=true
  kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1 && HAS_DEPLOYMENT=true
}

# ─── Status command ──────────────────────────────────────────────────────────
cmd_status() {
  hdr "Demo Data Manager — Current Status"
  detect_state

  if [ "$HAS_HTML" = true ]; then
    local v
    v=$(grep -oP 'APP_VERSION = "\K[^"]+' "$HTML_FILE" 2>/dev/null || echo "unknown")
    local s
    s=$(du -h "$HTML_FILE" | cut -f1)
    ok "HTML file: $HTML_FILE ($s, v$v)"
  else
    warn "HTML file: NOT FOUND at $HTML_FILE"
  fi

  if [ "$HAS_YAML" = true ]; then
    ok "Manifest: $YAML_FILE"
  else
    warn "Manifest: NOT FOUND at $YAML_FILE"
  fi

  if [ "$HAS_CONFIGMAP" = true ]; then
    ok "ConfigMap: ${CONFIGMAP} exists in ${NAMESPACE}"
  else
    warn "ConfigMap: NOT FOUND"
  fi

  if [ "$HAS_DEPLOYMENT" = true ]; then
    local pod_status
    pod_status=$(kubectl get pods -n "$NAMESPACE" -l app=demo-manager -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "—")
    ok "Deployment: ${DEPLOYMENT} (pod: ${pod_status})"
  else
    warn "Deployment: NOT FOUND"
  fi

  if [ "$HAS_DEPLOYMENT" = true ]; then
    local host
    host=$(hostname -f 2>/dev/null || hostname)
    echo
    log "Access URL: https://${host}/demo-manager/"
  fi
}

# ─── Validate files exist ────────────────────────────────────────────────────
require_html() {
  if [ ! -f "$HTML_FILE" ]; then
    err "HTML file not found: $HTML_FILE"
    echo "  Copy it first from your workstation:"
    echo "    scp demo-data-manager.html sysadmin@$(hostname):${INSTALL_DIR}/"
    exit 1
  fi
}

require_yaml() {
  if [ ! -f "$YAML_FILE" ]; then
    err "Manifest not found: $YAML_FILE"
    echo "  Copy it first from your workstation:"
    echo "    scp demo-manager.yaml sysadmin@$(hostname):${INSTALL_DIR}/"
    exit 1
  fi
}

# ─── First-time install ─────────────────────────────────────────────────────
cmd_install() {
  hdr "First-Time Install"
  preflight
  detect_state

  # Ensure folder exists
  if [ ! -d "$INSTALL_DIR" ]; then
    log "Creating directory $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
  fi
  require_html
  require_yaml

  # Rewrite Traefik API if needed
  if [ "$TRAEFIK_API" = "traefik.containo.us/v1alpha1" ]; then
    log "Rewriting manifest for legacy Traefik API"
    sed -i.bak 's|traefik.io/v1alpha1|traefik.containo.us/v1alpha1|g' "$YAML_FILE"
    ok "Manifest updated (backup: ${YAML_FILE}.bak)"
  fi

  # Apply ConfigMap
  if [ "$HAS_CONFIGMAP" = true ]; then
    log "ConfigMap exists — updating with new HTML"
    kubectl create configmap "$CONFIGMAP" \
      --from-file=index.html="$HTML_FILE" \
      -n "$NAMESPACE" --dry-run=client -o yaml | kubectl replace -f -
  else
    log "Creating ConfigMap from $HTML_FILE"
    kubectl create configmap "$CONFIGMAP" \
      --from-file=index.html="$HTML_FILE" -n "$NAMESPACE"
  fi
  ok "ConfigMap configured"

  # Apply manifest
  log "Applying k3s manifest"
  kubectl apply -f "$YAML_FILE"
  ok "Manifest applied"

  # Wait for pod readiness
  log "Waiting for pod to become ready..."
  if kubectl wait --for=condition=ready pod -l app=demo-manager -n "$NAMESPACE" --timeout=60s 2>/dev/null; then
    ok "Pod ready"
  else
    warn "Pod did not become ready within 60s. Check: kubectl logs -l app=demo-manager -n $NAMESPACE"
  fi

  hdr "Install Complete"
  local v
  v=$(grep -oP 'APP_VERSION = "\K[^"]+' "$HTML_FILE" 2>/dev/null || echo "unknown")
  local host
  host=$(hostname -f 2>/dev/null || hostname)
  ok "Version: v$v"
  ok "URL: https://${host}/demo-manager/"
  echo
  log "Next: open the URL in your browser. You should see Auto Mode (Same-Origin)."
}

# ─── Update existing install ────────────────────────────────────────────────
cmd_update() {
  hdr "Update HTML Only"
  preflight
  detect_state
  require_html

  if [ "$HAS_CONFIGMAP" = false ]; then
    err "ConfigMap doesn't exist — run install instead of update"; exit 1
  fi
  if [ "$HAS_DEPLOYMENT" = false ]; then
    err "Deployment doesn't exist — run install instead of update"; exit 1
  fi

  local v_old v_new
  v_new=$(grep -oP 'APP_VERSION = "\K[^"]+' "$HTML_FILE" 2>/dev/null || echo "unknown")
  v_old=$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.index\.html}' 2>/dev/null | grep -oP 'APP_VERSION = "\K[^"]+' || echo "unknown")
  log "Updating ConfigMap: v$v_old → v$v_new"

  kubectl create configmap "$CONFIGMAP" \
    --from-file=index.html="$HTML_FILE" \
    -n "$NAMESPACE" --dry-run=client -o yaml | kubectl replace -f -
  ok "ConfigMap updated"

  log "Restarting pod to pick up new ConfigMap"
  kubectl rollout restart deployment/"$DEPLOYMENT" -n "$NAMESPACE"
  kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=60s
  ok "Pod restarted"

  hdr "Update Complete"
  ok "Now serving v$v_new — hard-refresh browser (Ctrl+Shift+R)"
}

# ─── Uninstall ──────────────────────────────────────────────────────────────
cmd_uninstall() {
  hdr "Uninstall"
  preflight
  detect_state

  read -rp "$(printf "${YELLOW}Remove demo-manager from cluster? (y/N): ${NC}")" ans
  case "$ans" in
    y|Y|yes|YES) ;;
    *) log "Cancelled"; exit 0 ;;
  esac

  if [ "$HAS_DEPLOYMENT" = true ]; then
    log "Deleting manifest resources"
    kubectl delete -f "$YAML_FILE" --ignore-not-found 2>/dev/null || true
  fi
  if [ "$HAS_CONFIGMAP" = true ]; then
    log "Deleting ConfigMap"
    kubectl delete configmap "$CONFIGMAP" -n "$NAMESPACE" --ignore-not-found
  fi
  ok "Cluster resources removed"
  log "Files at $INSTALL_DIR were NOT deleted. Remove manually if desired:"
  echo "  rm -rf $INSTALL_DIR"
}

# ─── Dispatch ────────────────────────────────────────────────────────────────
case "${1:-}" in
  install)   cmd_install ;;
  update)    cmd_update ;;
  uninstall) cmd_uninstall ;;
  status)    cmd_status ;;
  "")
    # Auto-detect: install if no deployment exists, otherwise update
    preflight; detect_state
    if [ "$HAS_DEPLOYMENT" = true ]; then
      log "Existing deployment detected — running update"
      cmd_update
    else
      log "No existing deployment — running first-time install"
      cmd_install
    fi
    ;;
  *)
    echo "Usage: $0 [install|update|uninstall|status]"
    echo "Run with no arg for auto-detect."
    exit 1 ;;
esac
