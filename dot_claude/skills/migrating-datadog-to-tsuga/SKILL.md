---
name: migrating-datadog-to-tsuga
description: Use when migrating a service's Datadog monitors, dashboards or SLOs to Tsuga, or reviewing auto-imported ones (tag context:migration-run-*, "Review required" note, Datadog syntax in messages, per-env copies, empty or wrong values on imported objects).
---

# Migrating Datadog monitors and dashboards to Tsuga

## Overview
The Tsuga auto-import keeps Datadog names, formulas (often wrong), message syntax and broken layouts. The goal is correct, readable, verified monitors and dashboards, not a 1:1 copy. Simplest result wins: merge, drop, and fix Datadog bugs instead of copying them.

Rules: [monitors.md](monitors.md), [dashboards.md](dashboards.md), Tsuga quirks: [tsuga-gotchas.md](tsuga-gotchas.md). Read the ones you need before editing. Tsuga docs (`search-docs`, `get-doc-page`) override this skill when they disagree.

## Workflow
1. **Inventory** both sides: Tsuga by name search (`searchQuery`) AND `service` tag (manual DD monitors often lack it); Datadog monitors, dashboards and SLOs for the service, including ones created after the migration run. Note which DD monitors paged, and for which envs. Check whether the Tsuga objects are managed as code (repo search): if so, change the code, not the API. The Jira ticket's list can be stale: query Tsuga yourself.
2. **Data first**: for every metric/log field, check Tsuga has data under the real name, per env (high `limit` on every groupBy level). Run every imported filter on its own too: DD tags (`landing-zone:gcp`, `kube_*`) often don't exist in Tsuga and a filter matching nothing makes a monitor that never evaluates. Empty = ingestion gap or renamed metric: fix or report it, don't polish an empty widget. Compare every DD threshold with the real per-env values (7d max/p95) (monitors.md, Query).
3. **Monitors**: apply monitors.md. Set `validated:review` when done.
4. **Dashboards**: apply dashboards.md. Re-fetch the live dashboard before every write: the user edits in the UI.
5. **Verify**: replay each monitor query over 24h-7d with a bucket ≤ window/5. Run every dashboard widget query. Only then delete merged per-env copies.
   A replay can't prove delivery. Unless a real alert and recovery of this monitor are already in the tests channel, propose the live test (monitors.md), then ask the user for `validated:true`.
   Before reporting, check with data, not memory: every "equivalent to Datadog" claim against Datadog values, how often each monitor fires in the replay, what the new dashboard doesn't cover. Anything unproven (does `@team-sre` page, sample interval) is a question to the user, not a fact. State what the API can't prove (rendering, units, recovery notifications).
6. **Report**: what changed, what was dropped (with ids) and why, anything firing now. Jira (gotchas: Jira row): one short comment (about 5 lines: what exists, what was retuned vs DD, what was removed, what is unproven), edited in place with `commentId`, plus the description rewritten to the final objects. Then offer a short "beyond the rules" plan (coverage gaps, never-firing monitors, overlap, dashboard trims), ranked. Plan only until the user picks.
7. **Close**: when everything is `validated:true` and the DD monitors are gone (verify with a Datadog search), propose ticking the description task list and closing the ticket; do it only if the user says so (SRE project: chain transitions `5` → `6` → `7` → `8`, never `2` "Aborted").

## Ownership boundaries
- `validated`: new or reworked by you = `review`; only the user sets `true`, unless they explicitly delegate it.
- DD originals stay active until the Tsuga replacement is `validated:true`; deleting them is a separate step: ask first. DD dashboards are never deleted; only monitors go. Never write "removed" before verifying.
- Crossplane-managed DD monitors (`managed-by:crossplane`) are removed by a change in the values repo (local clone `$HOME/gitlab/idp/developer-control-plane/argocd-gcp-values`, not sourcebot): drop the app's `generic-kube.monitors` block and the then-unused `generic-kube` dependency in each env `Chart.yaml` (`dependencies: []`), check with `helm template`. `git status` first (the user may have edited already); never commit or push, suggest a title. Manual DD monitors: the user deletes them in the UI (Datadog tools are read-only).
- A live test mutates a monitor or cluster: state the exact changes, get an explicit yes, change nothing beyond it (if it goes wrong, restore and report).
- Never create or activate a paging notification rule. If the routing rules monitors.md expects are missing, tell the user.
- Merging per-env copies is the default (report it). Dropping a monitor with no replacement: explain why, then ask. Deleting imported Tsuga dashboards: only after the user has seen what the replacement doesn't cover.

## Quick reference
| Need | Do |
|---|---|
| Same monitor per env | One monitor, filter on exactly the envs the copies covered, `context.env` in groupBy |
| "Current" value on a dashboard | PromQL widget, not `last` |
| Which objects are broken (e.g. k8s/Crossplane) | Table, groupBy env/kind/name, `max` + `NOT status:True` |
| Message variable | `{{ alert_values[0] }}`, `{{ alert_transition }}`, `{{ alert_status }}` |
