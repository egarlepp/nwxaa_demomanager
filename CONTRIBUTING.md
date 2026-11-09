# Contributing

Thanks for helping improve the AA Demo Data Manager. It's a Greater Good side project, maintained on a best-effort basis.

## Ground rules

- **No real data.** Never commit or attach real customer data, credentials, tenant IDs, hostnames, session cookies or screenshots of real environments. Use obvious placeholders (`DEMO-PLACEHOLDER`, `aa.example.com`).
- **Lab instances only.** Test against a disposable AA install — see [SECURITY.md](SECURITY.md).
- **Verify, don't assume.** AA's internal APIs and schema change between versions. Check behaviour against a live instance before coding against it, and note the AA version you verified against in the code comment or PR.

## How the code is organised

Everything lives in `demo-data-manager.html`: a `<script type="text/babel">` block that Babel Standalone compiles in the browser. There is no build step, and the HTML file is both the source and the deployable artifact.

Keep it that way unless there is a strong reason not to. Prefer small, targeted edits over large rewrites — the file is big and diffs need to stay reviewable.

## Making a change

1. Fork the repo and create a branch.
2. Edit `demo-data-manager.html` (and `install-demo-manager.sh` / `demo-manager.yaml` if needed).
3. Bump `APP_VERSION` near the top of the script block, following [docs/ROADMAP.md#versioning](docs/ROADMAP.md#versioning), and add a matching entry at the top of [docs/CHANGELOG.md](docs/CHANGELOG.md).
4. Check locally (CI runs the same checks):

   ```bash
   (cd .github/scripts && npm install --no-save --no-package-lock @babel/parser@7.26.9 && node check-jsx.mjs ../../demo-data-manager.html ../../docs/CHANGELOG.md)
   ```

   ```bash
   shellcheck install-demo-manager.sh
   ```

5. Deploy to a lab AA instance with `./install-demo-manager.sh update`, hard-refresh, and run the flow you changed end to end.
6. Open a pull request describing what changed, why, and which AA version you tested against.

## Things to be careful with

- **Persisted keys.** Renaming anything stored in `localStorage` or in `cfg` breaks saved state and exported presets. If you must, add a migration.
- **`cronEnabled` must stay `false`** on created scans — otherwise AA will try to scan the fake hosts.
- **Supported versions.** Only add an AA version to `AA_SUPPORTED_VERSIONS` after the Compatibility check shows no schema drift against it.
