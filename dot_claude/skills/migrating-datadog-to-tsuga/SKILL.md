---
name: migrating-datadog-to-tsuga
description: Use when migrating a service's Datadog monitors, dashboards or SLOs to Tsuga, or reviewing auto-imported ones (tag context:migration-run-*, "Review required" note, Datadog syntax in messages, per-env copies, empty or wrong values on imported objects).
---

# Migrating Datadog monitors and dashboards to Tsuga

## Overview
The Tsuga auto-import keeps Datadog names, formulas (often wrong), message syntax and broken layouts. The goal is correct, readable, verified monitors and dashboards, not a 1:1 copy. Simplest result wins: merge, drop, and fix Datadog bugs instead of copying them.

Rules: [monitors.md](monitors.md), [dashboards.md](dashboards.md), Tsuga quirks: [tsuga-gotchas.md](tsuga-gotchas.md). Read the ones you need before editing. Tsuga docs (`search-docs`, `get-doc-page`) override this skill when they disagree.

## Workflow
1. **Inventory** both sides: Tsuga by name search (`searchQuery`) AND `service` tag (manual DD monitors often lack it); Datadog monitors, dashboards and SLOs for the service, including ones created after the migration run. Note which DD monitors paged, and for which envs. Check whether the Tsuga objects are managed as code (repo search): if so, change the code, not the API.
2. **Data first**: for every metric/log field, check Tsuga has data under the real name, per env (high `limit` on every groupBy level). Empty = ingestion gap or renamed metric: fix or report it, don't polish an empty widget.
3. **Monitors**: apply monitors.md. Set `validated:review` when done.
4. **Dashboards**: apply dashboards.md. Re-fetch the live dashboard before every write: the user edits in the UI.
5. **Verify**: replay each monitor query over 24h-7d with a bucket ≤ window/5 (no false positives; past incidents would fire). Run every dashboard widget query; KPIs consistent with lists. Only then delete merged per-env copies. State what the API can't prove (rendering, wildcards).
6. **Report**: what changed, what was dropped or lost (with ids) and why, anything firing now and why. Then offer a short "beyond the rules" plan (coverage gaps, dead or never-firing monitors, overlap, user-facing vs mechanics signals, dashboard trims), ranked by value. Plan only; apply nothing until the user picks.

## Ownership boundaries
- `validated` (monitors and dashboards): new or reworked by you = `review`; only the user sets `true`, unless they explicitly delegate it.
- The Datadog originals stay active until the Tsuga replacement is `validated:true`; deleting them is a separate step: ask first.
- Never create or activate a paging notification rule. If the routing rules monitors.md expects are missing, tell the user.
- Merging per-env copies is the agreed default (report it). Dropping a monitor with no replacement: explain why, then ask.

## Quick reference
| Need | Do |
|---|---|
| Same monitor per env | One monitor, filter on exactly the envs the copies covered, `context.env` in groupBy |
| "Current" value on a dashboard | PromQL widget, not `last` |
| Which objects are broken (e.g. k8s/Crossplane) | Table, groupBy env/kind/name, `max` + `NOT status:True` |
| `field:404` returns 0 | `field:[404 TO 404]`, `field:>=400` |
| Message variable | `{{ alert_values[0] }}`, `{{ alert_transition }}`, `{{ alert_status }}` |
