# Dashboard rules

## Content
- Answer the same questions as Datadog, rebuilt on Tsuga names. Re-derive every formula (DD had missing `/60`, `×8` on bytes).
- DD dashboards can be silently empty too (old `*.count` names vs `*_total`, upstream renames). Build on names with data now.
- Fix DD bugs (wrong status ranges, typos, inverted semantics). Drop auto-generated junk (`nan` titles, splits on missing tags).
- Remove the "Review required" note, `[TO_KEEP]` prefixes, Datadog links, DD template-variable names.
- Empty request/limit metrics usually mean the pod spec sets none: check manifests before blaming Tsuga.
- Before investing in new ingestion for a missing source, check whether anything alerts on it.

## Rebuilding from imports
- Imports are often several overlapping dashboards (one with a widget per metric). Build one dashboard per stack from the kept DD dashboards' sections (`[TO_KEEP]` ones; the Tsuga import still holds their queries and layout, read it from the saved output). Size it for what they showed (a 17-widget rebuild of 80 was rejected). Merge duplicates (avg/max/sum variants, dozens of conntrack series) into one widget; drop "Not migrated" notes.
- Before publishing: every metric has data (one `aggregate-scalar`, no groupBy), every filter/groupBy label has data (values are case-sensitive). Skip all-zero metrics and metrics absent from Tsuga; list them as not rebuilt.
- Before deleting the imports, give the user the list of what is not covered; keep their definitions until they are happy.
- Generate widgets with a script that assigns ids/layout and asserts every row tiles to 12; paste its JSON into the call.

## Filters
- DD template variables → dashboard filters on real Tsuga attributes, same defaults. Don't hardcode them in every widget.
- A dashboard filter applies to every widget: never filter on an attribute only some widgets carry. Scope that widget instead.

## Layout
- 12-column grid; every row tiles exactly.
- Section headers: note `## Title` with `noteColor`, `h=1`, full width, rotating `blue.200` / `emerald.200` / `amber.200` / `red.200` / `violet.200`.
- No intro or explanatory notes; keep only notes carrying reference data.
- KPI query-values `h=2`, `backgroundMode: background`. Colour conditions: shape unknown (in no existing widget), skip and report. Charts with `legendMode: table` need `h=6`.
- Order like DD; for traffic pairs, ingress left and egress right.

## Units
- Every numeric widget has a normalizer: `data`/`B`, `duration`/unit, `percent` (0-100) vs `percent-fraction` (0-1), `custom` (`req/s`, `cores`, `Gbps`).
- Counters: use the rate function the DD widget had (`functions: [{"type": "per-minute"}]` or `per-second`); a plain `sum` of a delta counter changes scale with the zoom. Avoid `sum` on duplicated samples.
- Gauge `sum` adds every series in a bucket (pod rotation shows 2-3): use `max` for "is there one?".
- Decimal network bits: `q1 * 8 / 1000000000` + custom `Gbps` (built-in bit units are binary).

## "Now" values and object lists
- `last` keeps the last sample of every series seen in the window: values change with the time range. For "now" use PromQL widgets (`query-value-promql`, `queries: ["..."]`, quote dotted labels `by ("gvk")`); dashboard filters still apply. `> 0` hides healthy groups.
- KPIs as `sum(all) - sum(ok)` are the source of truth.
- PromQL top lists freeze on the last non-empty state when every row disappears. For "which objects are broken" use a `table`: up to 3 groupBy levels, one column per condition (e.g. `max`, filter `NOT status:True`), title "(selected window)". Set widths with `columnSizes` (`label`, `col-0`, ...): UI resizing isn't saved.
- Keep PromQL top lists for few-row by-kind counts.
- Top-N groupBy limits rank by the first query, not the formula: use a high limit (100).

## Folder, applying
- One folder per service stack, under the top-level `SRE` folder, named after the stack, tagged `service:<service_name>`. Reuse it if it exists (`query-dashboard-folders`), else `create-dashboard-folder`.
- `update-dashboard` with `graphs` replaces all widgets (filters, tags, folder kept when omitted; don't overwrite the user's default filter value); only from a fresh `get-dashboard`. `update-dashboard-graph` for one widget.
- Widget shapes (copy from an existing dashboard): `timeseries` queries `[{aggregate, filter?, functions: []}]` + `visibleSeries`; `groupBy` one field per level; `query-value-promql` `queries: ["..."]`.
- Tags: `team`, `service`, `origin-id` (DD id), `validated`. Link: `https://app.tsuga.com/dashboards/<id>`.
