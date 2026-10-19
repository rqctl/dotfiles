# Tsuga gotchas (seen in practice)

| Symptom | Fix |
|---|---|
| A group is missing from a multi-level groupBy result | Groups beyond each level's `limit` are dropped, not merged. Set a high `limit` on every level; when in doubt, one level per call. |
| Later queries in one aggregate call come back empty | Seen when one query filled the shared limit: one query per call, or a limit well above the group count. |
| `field:404` returns 0 on a numeric field | `field:[404 TO 404]` or `field:>=400`. |
| `-status:True` returns nothing | `NOT status:True`. |
| PromQL `or` with a `0` sentinel | Internal server error; don't. |
| Widget needs its own time range | Not supported (only `timeBucket`); tables aggregate the whole window. |
| `context.` prefix missing in metric metadata | `context.<attr>` still resolves in filters and groupBy. |
| `*` in a dashboard filter value | Wildcard behaviour isn't checkable via the API: ask the user to check the UI. |
| `aggregate-*` rejects `queries` | Each query is `{"aggregate": {"type": "max", "field": "<metric>"}, "filter": "..."}`. `aggregate-scalar` groupBy: one field per level (use two levels). `get-tool-schema` returns nothing useful: copy the shape from an existing monitor. |
| Tool output "exceeds maximum" (notification rules, long timeseries) | Saved to a file: parse with `python3 -I`, don't re-query. Shapes differ: rules file = `[{type, text}]` with `text` = `[Resource ...] {json}`; timeseries file = `{series: [...]}`. |
| Formula series in a timeseries | Returned with `id: "value"` next to `q1`, `q2`. |
| Jira description edit (keeps task lists) | believe MCP `editJiraIssue`: `contentFormat: html` only, a `task-list` round-trips. claude.ai MCP: ADF, but `getJiraIssue` may return markdown despite `adf`: then don't rewrite, comment. Read back as markdown to check `[x]`. Edit a comment with `commentId`. |
