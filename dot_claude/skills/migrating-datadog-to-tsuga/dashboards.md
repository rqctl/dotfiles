# Dashboard rules

## Content
- Answer the same questions as Datadog, rebuilt on Tsuga names. Re-derive every formula (DD had missing `/60`, `×8` on bytes).
- DD dashboards can be silently empty too (old `*.count` names vs `*_total`, upstream renames). Build on names with data now.
- Fix DD bugs (wrong status ranges, typos, inverted semantics). Drop auto-generated junk (`nan` titles, splits on missing tags).
- Remove the "Review required" note, `[TO_KEEP]` prefixes, Datadog links, DD template-variable names.
- Status breakdown charts (sync, health): filter out the dominant OK state (`NOT context.sync_status:Synced`), else it hides the series that matter.
- Empty request/limit metrics usually mean the pod spec sets none: check manifests before blaming Tsuga.
- Before investing in new ingestion for a missing source, check whether anything alerts on it.

## Rebuilding from imports
- Imports are often several overlapping dashboards (one with a widget per metric). Build one dashboard per stack from the kept DD dashboards' sections (`[TO_KEEP]` ones; the Tsuga import still holds their queries and layout, read it from the saved output). Size it for what they showed. Merge duplicates (avg/max/sum variants, dozens of conntrack series) into one widget; drop "Not migrated" notes.
- Before publishing: every metric has data (one `aggregate-scalar`, no groupBy), every filter/groupBy label has data (values are case-sensitive). Skip all-zero metrics and metrics absent from Tsuga; list them as not rebuilt.
- Before deleting the imports, give the user the list of what is not covered; keep their definitions until they are happy (saved under `$HOME`, not the scratchpad, which can vanish mid-session). The user decides: delete only on their word.
- Generate widgets with a script that assigns ids/layout and asserts every row tiles to 12; paste its JSON into the call.

## Filters
- DD template variables → dashboard filters on real Tsuga attributes, same defaults. Don't hardcode them in every widget.
- A dashboard filter applies to every widget: never filter on an attribute only some widgets carry (e.g. a field absent from one log type). Scope that widget instead.
- A DD default value that narrows the whole dashboard (e.g. a path prefix) makes every widget cover a small slice of the traffic: leave it empty unless the dashboard's name says so.
- Check what a zero/unscored sentinel value means before counting it in a ratio.

## Empty widgets
- Empty because nothing is wrong (a non-INFO log list, an error list): keep. Always empty or zero (no source, no label values): delete it and re-tile the row.

## Layout
- 12-column grid.
- Section headers: note `## Title` with `noteColor`, `h=1`, full width, rotating `blue.200` / `emerald.200` / `amber.200` / `red.200` / `violet.200`.
- No intro or explanatory notes; keep only notes carrying reference data (links, ids, what the linked monitor covers).
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
- PromQL top lists freeze on the last non-empty state when every row disappears. For "which objects are broken" use a `table`: up to 3 groupBy levels, one column per condition (e.g. `max`, filter `NOT status:True`), title "(selected window)". Not for objects that flap during rollouts (non-Synced while syncing): the table becomes an endless list, chart the non-OK count or drop it. Set widths with `columnSizes` (`label`, `col-0`, ...): UI resizing isn't saved.
- Keep PromQL top lists for few-row by-kind counts.
- A PromQL "now" widget you can't verify with `query-promql` (dotted labels quoted) isn't worth shipping: use a timeseries and report that the value is windowed.
- Top-N groupBy limits rank by the first query, not the formula: use a high limit (100).

## Folder, applying
- One folder per service stack, under the top-level `SRE` folder, named after the stack, tagged `service:<service_name>`. Reuse it if it exists (`query-dashboard-folders`), else `create-dashboard-folder`.
- `update-dashboard` with `graphs` replaces all widgets (filters, tags, folder kept when omitted; don't overwrite the user's default filter value); only from a fresh `get-dashboard`. `update-dashboard-graph` for one widget. No delete-widget call: deleting means resending the full `graphs` array (copy the compact JSON of the `get`, drop widgets, fix the layout). A `filters`-only `update-dashboard` is safe.
- Widget shapes (copy from an existing dashboard): `timeseries` queries `[{aggregate, filter?, functions: []}]` + `visibleSeries`; `groupBy` one field per level; `query-value-promql` `queries: ["..."]`.
- Tags: `team`, `service`, `origin-id` (DD id); no `validated` tag (the folder organization validates implicitly). Link: `https://app.tsuga.com/dashboards/<id>`. Owner: the team that owns the service's monitors; if the import's owner differs, ask the user once instead of leaving it.
