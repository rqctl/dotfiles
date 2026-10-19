# Tsuga gotchas (seen in practice)

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
| `aggregate-*` rejects `queries` | Each query is `{"aggregate": {"type": "max", "field": "<metric>"}, "filter": "..."}`. `get-tool-schema` returns nothing useful: copy the shape from an existing monitor or dashboard. |
| groupBy shape | Monitor `groupByFields` take several fields per entry; dashboard widgets and `aggregate-scalar` take one field per level. |
| Tool output "exceeds maximum" (rules, timeseries, `list-metrics`, dashboards) | Saved to a file: parse with `python3 -I`, don't re-query. Rules: `[{type, text}]` with `text` = `[Resource ...] {json}`; timeseries: `{series: [...]}`; `list-metrics`: `{items: [{name, type, temporality, attributes}]}`, filter by name prefix. |
| Formula series in a timeseries | Returned with `id: "value"` next to `q1`, `q2`. |
| Counter values | Counters have `delta` temporality: `sum` per bucket = count in the bucket. |
| Datadog side | `get_datadog_metric` takes raw `avg:`/`sum:` query strings. `execute_code` has no `datadog` global. `search_datadog_monitors` with no match returns an empty result. |
| Reading alerts in Slack | `slack_read_channel` with `oldest` (message ts); `slack_search_*` with `after:` returned nothing. Attachments hold the group tags and the rendered message. |
| Jira description edit (keeps task lists) | believe MCP (`mcp-portal` `atlassian_editJiraIssue`, `contentFormat: html`) round-trips a `task-list`; a ticked item is `data-state="DONE"` + `<input type="checkbox" checked>`. claude.ai MCP: `getJiraIssue` returns markdown even with `adf`: use it to comment, not to rewrite. Edit a comment with `commentId`. |
