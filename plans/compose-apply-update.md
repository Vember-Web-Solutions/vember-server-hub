---
node: compose-apply-update
title: Apply update action for Compose-managed containers
status: done
created: 2026-11-19
tags: [docker, containers, compose]
---

# Apply update action for Compose-managed containers

## Goal

Make the Containers tab able to *apply* a pulled image update, not just download
it. One button inspects the selected container's Compose labels, confirms, and
recreates only that service from its compose file.

## Scope

In:
- `Docker.inspectComposeCommand`, `parseComposeInfo`, `applyComposeUpdateCommand`.
- Two-step Panel process chain (inspect → compose up) with status, result,
  notification and shared busy guard.
- Confirm dialog in HubPanel, button and result text in ContainersTab.
- Tests, version bump, live check on paperless-ngx.

Out:
- Recreating containers that were started with plain `docker run` (Minecraft).
  They get a clear "not managed by Compose" message instead.
- Pulling images automatically. The operator still chooses Pull image first.
- Recreating dependent services (`--no-deps`).

## Decisions

- `--no-deps` keeps db/broker up when applying a webserver update. Our last
  full `compose up -d` recreated all three, which was more churn than needed.
- All values are passed as argv, never shell text. Config paths must be
  absolute; project and service names are restricted to `[A-Za-z0-9_-]`.
- Confirmation mirrors the existing prune dialog, since recreation causes a
  brief outage.

## Steps

1. Model helpers + tests for parsing real Compose labels and rejecting junk.
2. Panel state, functions and processes; expose result in `status()`.
3. HubPanel confirmation property + new dialog component; ContainersTab button.
4. QML structure guards, mutation check, full suite, qmllint, plugin validate.
5. Version bump, live apply on paperless-ngx, journal check, commit and push.

## Risks

- Compose labels can hold multiple config files separated by commas; both must
  become separate `-f` arguments in order.
- `--project-directory` is needed so a relative `env_file` in the compose file
  still resolves.
- A container with no Compose labels must fail with an explanatory message,
  not a blank result or a stuck busy flag.
- Process `onExited` must clear `dockerBusy` on every path, or every Docker
  action stays disabled afterwards.

## Done when

The Containers tab can apply an update to a Compose-managed container in one
confirmed click; paperless-ngx applies cleanly on the live check; all guards,
lint and plugin validation pass and the change is pushed.
