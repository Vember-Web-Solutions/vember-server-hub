---
node: paperless-file-server-wizard
title: Guided file server wizard for Paperless-ngx
status: draft
created: 2026-11-20
tags: [wizard, docker, paperless, storage, planning]
---

# Guided file server wizard for Paperless-ngx

## Goal

A hub wizard that turns a fresh machine into a document digitizing server: it
sets up Docker, creates a Paperless-ngx stack, and opens it on a free port —
without Elena writing compose files or picking paths by hand.

## Scope

In (future):
- Reuse the four-step server wizard shape: role choice → runtime preflight →
  options → review/create.
- Docker preflight and image pull through the existing `Docker.mjs` helpers.
- A Paperless-ngx recipe: `paperless-ngx` + Postgres + Redis, with a named
  compose project, persistent data under the games mount, and a bind-mounted
  `consume` folder for papers to drop into.
- Reuse the 25565–25584 port pool and one-click Launch chain so a created
  document server gets its own free port and opens in a browser from the hub.
- OCR language and timezone choices as dropdowns; memory sized to the machine.
- Idempotent: detect an existing stack and refuse to overwrite its data.

Out:
- Scanner hardware or SANE driver setup.
- Training OCR models or custom classification rules.
- Off-site backup and retention policy beyond sane initial defaults.
- Any destructive change to existing server data.

## Steps

1. Model helpers (pure): compose renderer, environment file renderer, and a
   parser for the chosen options. Tests cover quoting, paths, and port mapping.
2. Preflight: verify Docker is installed/running, pull the three images with
   progress in the wizard log, and surface failures before creating anything.
3. UI: role card for "Document server (Paperless-ngx)", options for data dir,
   consume dir, OCR languages, timezone, and the shared Port dropdown.
4. Review step prints the full compose file and commands before anything runs.
5. Wire creation into the server list and the one-click Launch chain.
6. Document the first-run flow: where to drop papers, how to reach the UI, and
   how to stop/restart the stack from the hub.

## Risks

- Paperless indexing is memory-hungry; a small default can make first import
  crawl. Size from detected RAM and allow an override.
- The games mount must exist before data is written; preflight must fail early
  with a clear message rather than creating a directory on the root drive.
- Port pool overlap with a second Minecraft server is handled by the shared
  allocator, but the browser URL must use the same chosen port.
- Existing Paperless stacks must never be silently adopted or overwritten.

## Collaboration

Elena chose (2026-11-20): coordinate with Echo through Dispatch. Arcade owns
the wizard and Docker setup; Echo advises on runtime tuning (OCR languages,
memory, storage layout, image pins). Letter sent:
`~/Projects/dispatch/store/arcade/dispatch-paperless-wizard-echo-coordination-20261120.md`.

## Current state to respect

Paperless already runs on vemberos: `paperless-ngx-webserver-1`
(`192.168.0.145:9999->8000`), `-db-1` (Postgres 18), `-broker-1`
(valkey/valkey:9-alpine); media/export are bind-mounted under
`~/Documents/Paperless/`. The wizard must never adopt or overwrite it. Echo's
separate `hub-container-db-backups` thread is map-out only — no build.

## Done when

A fresh install can complete the wizard, create a reachable Paperless-ngx stack
on a free port, launch it with one click, and re-run the wizard without
touching existing data.
