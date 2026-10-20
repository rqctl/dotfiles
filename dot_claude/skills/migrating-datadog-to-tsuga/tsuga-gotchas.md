# Tsuga gotchas (seen in practice, last verified 2026-10)

API shapes and tool behavior change with Tsuga releases: confirm a row against a live `get-*` call or the docs before relying on it, and when a row proves wrong, fix or delete it in the same session.

| Symptom | Fix |
|---|---|
| A group is missing from a multi-level groupBy result | Groups beyond each level's `limit` are dropped, not merged (highest values are kept first). Set a high `limit` on every level; when in doubt, one level per call. |
| Later queries in one aggregate call come back empty | One query filled the shared limit: one query per call, or a limit well above the group count. Up to 15 queries with no groupBy is fine for existence checks. |
| `field:404` returns 0 on a numeric field | `field:[404 TO 404]` or `field:>=400`. |
| `-status:True` returns nothing | `NOT status:True`. |
| A filter on a label value matches nothing | Values are case-sensitive and differ from the DD tags (`ERROR`, `INGRESS`, `NetworkPolicy`): list them with a groupBy first. |
| PromQL `or` with a `0` sentinel | Internal server error; don't. |
| Widget needs its own time range | Not supported (only `timeBucket`); tables aggregate the whole window. |
| `context.` prefix missing in metric metadata | `context.<attr>` still resolves in filters and groupBy. |
| `*` in a dashboard filter value | Not checkable via the API: ask the user to check the UI. |
| `aggregate-*` rejects `queries` | Each query is `{"aggregate": {"type": "max", "field": "<metric>"}, "filter": "..."}`. |
| Tool argument shapes | `get-tool-schema` works with `property` (and `variant` for union types, e.g. `configuration` `metric`, `graphs` `timeseries`); also check shapes against an existing monitor or dashboard (`get-monitor`/`get-dashboard`) before trusting this file. |
| Monitor config values | `noDataBehavior`: `alert`, `resolve`, `keep_last_status`, `consider_zero`. `update-monitor` keeps `dashboardId` and folder when omitted (per the tool description, untested); send everything else (see the required-fields row below). |
| `update-monitor`/`create-monitor` fail with "`priority` must be equal to one of the allowed values" | The tool schema isn't loaded (deferred tool): `priority` is sent as a string. Load it with ToolSearch before the first call, for every deferred Tsuga write tool. |
| `update-monitor`/`create-monitor` reject the call with "must have required property" | `update-monitor` replaces the monitor: send `name`, `owner`, `priority`, `permissions` and `configuration` every time, and `message` and `tags` too (don't rely on omitted ones being kept). Every metric query needs a `filter` (empty string for none). |
| groupBy shape | Monitor `groupByFields` take several fields per entry; dashboard widgets and `aggregate-scalar` take one field per level. |
| Tool output "exceeds maximum" (rules, timeseries, `list-metrics`, dashboards) | Saved to a file: parse with `python3 -I`, don't re-query. Rules: `[{type, text}]` with `text` = `[Resource ...] {json}`; timeseries: `{series: [...]}`; `list-metrics`: `{items: [{name, type, temporality, attributes}]}`, filter by name prefix. |
| Formula series in a timeseries | Returned with `id: "value"` next to `q1`, `q2`. |
| Counter values | Counters have `delta` temporality: `sum` per bucket = count in the bucket. |
| Datadog side | `get_datadog_metric` takes raw `avg:`/`sum:` query strings. `execute_code` has no `datadog` global. `search_datadog_monitors` with no match returns an empty result. |
| Reading alerts in Slack | Channel id from `slack_search_channels`; `slack_read_channel` with `oldest` = Unix timestamp (check the year: `date -u -d '<date>' +%s`, a wrong one returns old messages); `slack_search_*` with `after:` returned nothing. Attachments hold the group tags, the rendered message and the monitor id. |
| Timeseries call times out or exceeds the output limit | 5-10m buckets, one groupBy level, narrower filter; parse the saved file. Per-pod/per-node groupBys over 7d are the worst. |
| Datadog `search_datadog_monitors` | One word per query (a long `OR` returned a subset); a product name matches every "managed by <product>" footer: search by `service:` tag or id. |
| Jira description edit (keeps task lists) | believe MCP (`mcp-portal` `atlassian_editJiraIssue`, `contentFormat: html`) round-trips a `task-list`; a ticked item is `data-state="DONE"` + `<input type="checkbox" checked>`. claude.ai MCP: `getJiraIssue` returns markdown even with `adf`: use it to comment, not to rewrite. Edit a comment with `commentId`. `addOrEditJiraIssueComment` echoes `jsmCommentType: publicComment` even on the SRE project: unverified whether that is visible outside the team, so write comments safe to read publicly. |
