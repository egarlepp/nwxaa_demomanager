# Security Policy

## Intended use

The AA Demo Data Manager is a **lab and demo tool**. By design it:

- writes synthetic rows directly into AA's ClickHouse database through Metabase, and can `TRUNCATE` / `ALTER … DELETE` those tables;
- asks you to grant the Metabase ClickHouse user `INSERT, TRUNCATE, ALTER DELETE, ALTER UPDATE ON access_analyzer.*` and `SYSTEM RELOAD DICTIONARY, SYSTEM REFRESH VIEW ON *.*`;
- creates and deletes AA service accounts, sources, scans and scan executions through the AA REST API — the "Full" wipe mode deletes **all** of them, not only ones it created;
- generates a shell script that runs SQL against AA's PostgreSQL database via `kubectl exec`.

**Only run it against disposable AA instances you own.** Do not use it on production or customer systems, and do not leave the elevated ClickHouse grants in place on any instance that holds real data.

The app has no backend and stores nothing outside your browser. Connection settings and run history are kept in the browser's `localStorage`. It acts with the permissions of the AA session you are logged in with.

## Supported versions

Only the latest release on the default branch receives fixes.

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub's private reporting instead: **Security → Report a vulnerability** on this repository. Include the affected version (`APP_VERSION`, shown in the app header), steps to reproduce, and the impact.

This is a volunteer-maintained project, so responses are best-effort — expect an acknowledgement within about a week.

Vulnerabilities in Netwrix Access Analyzer itself should be reported to Netwrix, not here.
