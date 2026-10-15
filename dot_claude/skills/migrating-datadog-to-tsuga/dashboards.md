# Dashboard rules

## Content
- Answer the same questions as Datadog, rebuilt on Tsuga names. Re-derive every formula (DD had missing `/60`, `×8` on bytes).
- DD dashboards can be silently empty too (old `*.count` names vs `*_total`, upstream metric renames). Build on names with data now.
- Fix DD bugs (wrong status ranges, typos, inverted semantics). Drop auto-generated junk (`nan` titles, splits on missing tags) and say what was dropped.
- Remove the "Review required" note, `[TO_KEEP]` prefixes, Datadog links, DD template-variable names.
- Empty request/limit metrics usually mean the pod spec sets none: check manifests before blaming Tsuga.
- Before investing in new ingestion for a missing source, check whether anything alerts on it.

## Filters
- DD template variables → dashboard filters on real Tsuga attributes, same defaults. Don't hardcode them in every widget.
- A dashboard filter applies to every widget: never filter on an attribute only some widgets carry (it blanks the others). Scope that widget instead.

## Layout
- 12-column grid; every row tiles exactly (check by script).
- Section headers: note `## Title`, `h=1`, full width, rotating `blue.200` / `emerald.200` / `amber.200` / `red.200` / `violet.200`.
- No intro or explanatory notes; keep only notes carrying reference data (e.g. an id per env).
- KPI query-values `h=2`, `backgroundMode: background`, colour conditions. Charts with `legendMode: table` need `h=6`.
- Order like DD; for traffic pairs, ingress left and egress right.

## Units
- Every numeric widget has a normalizer: `data`/`B`, `duration`/unit, `percent` (0-100) vs `percent-fraction` (0-1), `custom` (`req/s`, `Gbps`).
- Match the DD widget's meaning: rate (`per-second`, per-minute delta gauges `/ 60`) only where DD showed a rate. Avoid `sum` on duplicated samples.
- Gauge `sum` adds every series in a bucket (pod rotation shows 2-3): use `max` for "is there one?".
- Decimal network bits: `q1 * 8 / 1000000000` + custom `Gbps` (built-in bit units are binary).

## "Now" values and object lists
- `last` keeps the last sample of every series seen in the window, including ended ones: values change with the time range. For "now" use PromQL widgets (`query-value-promql`, `queries: ["..."]`, quote dotted labels `by ("gvk")`); dashboard filters still apply. `> 0` hides healthy groups.
- KPIs as `sum(all) - sum(ok)` are the source of truth.
- PromQL top lists freeze on the last non-empty state when every row disappears. For "which objects are broken" use a `table`: up to 3 groupBy levels (e.g. env / kind / name), one column per condition (e.g. `max`, filter `NOT status:True`), title "(selected window)". Set widths with `columnSizes` (`label`, `col-0`, ...): UI resizing isn't saved.
- Keep PromQL top lists for few-row by-kind counts (a table can't hide 0 rows).
- Top-N groupBy limits rank by the first query, not the formula: use a high limit (100).

## Applying
- `update-dashboard-graph` for one widget; full `update-dashboard` only from a fresh `get-dashboard` (to remove widgets).
- Tags: `team`, `service`, `origin-id` (DD id), `validated`.
