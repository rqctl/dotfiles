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
