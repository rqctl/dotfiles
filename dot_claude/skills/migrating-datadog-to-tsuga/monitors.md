# Monitor rules

Audit every field against the Datadog original: name, message, query, thresholds, window, no-data behavior, alert logic, priority, tags, routing.

## Scope
- **Per-env copies → one monitor** when they differ only by env filter: filter on exactly the envs the copies covered (e.g. `context.env:(int OR sta OR prd OR shd)`), `context.env` in groupBy. Delete the copies only after the merged monitor is replayed. Keep prd separate if it needs different thresholds or routing.
- Region like env: not in the name, no `region` tag; the alert group (e.g. cluster name) carries it.
- DD drafts were imported live ("monitor was a draft in Datadog" in migration notes): decide keep or delete, don't leave them firing by accident.
- Exclude envs where the component doesn't run instead of keeping a monitor that never has data.
- Drop monitors that can't realistically fire or always fire. Say why, ask before deleting.
- Group by the real unit of failure (e.g. per leader-election lease, not summed across leases).

## Name
- No template variables in the name: the notification adds the group values on its own line.
- `[ENV]` prefix only when the monitor genuinely exists per env.
- Otherwise start with the product as plain words, no brackets; avoid ambiguous bare acronyms.

## Message
- Tsuga syntax only `{{ variable }}` (full list: threshold monitor doc). Useful: `alert_status`, `alert_transition`, `alert_triggered_by` (grouped monitors only), `alert_values[0]`, `alert_thresholds[0]`, `alert_timeframe`, `alert_data_url`, `monitor_url`, `dashboard_url`. Unknown variables render literally. No rounding filter works.
- Remove `{{#is_alert}}`, `{{/is_alert}}`, `{{!-- --}}`, `{{x.name}}`, `@` handles, Datadog links, false "managed by Terraform" notes, "Migration notes". A DD notebook runbook link goes with them: report that the runbook needs porting.
- One message for alert, no-data and recovery: state-neutral wording plus `{{ alert_transition }}`.
- Fix DD copy/paste errors.

## Mapping Datadog settings
- Multi alert → groupBy + alert logic "for each matching value"; simple alert → "if any match".
- `notify_no_data:true` → no-data `alert` (where silence means outage); otherwise `resolve` or `keep_last_status`.
- Warning / recovery thresholds, OR-composites, custom eval frequency: no direct equivalent. Split, or report what is lost.
- Renotify lives on the notification rule's destination, not the monitor.
- Anomaly on a continuous metric → anomaly detection monitor; on a binary/state metric → plain threshold. Forecast → threshold or report as dropped. DD SLOs → Tsuga SLOs.

## Query
- Check the data shape first: duplicated exporter samples inflate `sum`; ingestion lag makes a windowed `sum` undercount. For one-sample-per-minute gauges, `average` with a per-minute threshold (DD `sum(last_Nm)` threshold ÷ N) avoids both. Never for log/span counts.
- A DD `== N` on a difference rarely means "exactly N missing": check the intent, prefer `>` with a threshold that survives one missed sample, check against the 7d replay.
- Averaging across series dilutes one real backlog: use `max` when one bad series matters.
- Don't copy a DD `evaluation_delay` as `time-offset` unless Tsuga data lags. No `fill: zero` on lagging metrics.
- Ratio monitors: a counter with no errors may have no series. Set that query's missing value to `0` and confirm by replay.
- **Thresholds**: compare each DD threshold with 7d real values per env. Units change (DD `container.cpu.usage` nanocores, Tsuga cores: `4e9` → `4`); a threshold far above anything observed can never fire. Retuning is fine (keep the intent, say what changed and why, replay clean).
- **Counters**: DD `avg:` averages across series (per-pod mean) and over time; a Tsuga `sum` across pods is not the same. Query both in Datadog (`avg:` vs `sum:`, same grouping, 5m buckets) to see the scale and whether the threshold ever fired, then choose. Never write "equivalent" without that check.
- **Histograms**: DD `.bucket`/`.sum` averages are meaningless: use `percentile` (e.g. p95). `count` on a histogram counts observations (e.g. `return_code:429`).
- A metric emitted only above a threshold (e.g. Cilium policy map pressure, above 10% utilization) has no data while healthy: no-data `resolve`, say it can't be replayed. Check the upstream doc before calling a monitor dead.
- Before alerting on a near-full or high value, trace it: peak vs average per env and per node, peak duration, impact at that moment (drops, errors). A one-minute peak that clears itself with no impact is not an alert.
- Replay: 1-2m buckets over 7d (saved file), rolling window in `python3 -I`, count firing episodes per group. Report how often it fires.
- Logs/spans: Tsuga query syntax, not DD: no `-field` (use `NOT`), uppercase `AND`/`OR`/`NOT`, uppercase levels (`level:ERROR`), no `@` attribute prefix, span `duration` in ms. DD `trace.*` metrics → span metrics or a trace monitor.

## Tags and routing
- Keep `team`, `service`, `origin-id` (DD id), `validated`, plus meaningful ones (`env` when per-env).
- Drop import tags: `source`, `origin`, `context`, `migration-status`, false `managed_by:terraform`.
- `validated`: `false` raw import → `review` reworked by us → `true` user-confirmed (user only).
- Priority: keep the DD priority unless clearly wrong; imported priorities don't reflect paging.
- `oncall:true` only when the DD version paged (check DD `notifications`/message, and ask what the handle routes to). If only some env copies paged, the paging rule must also match `context.env:prd`, or keep prd as its own monitor.
- Routing is by notification rules, not `@` handles (check `list-notification-rules`): `NOT validated:true` → tests channel, `validated:true` → team channel, `validated:true AND oncall:true` → paging (user activates).

## Live test (replay can't prove alert + recovery)
Skip it if a real alert and recovery of this monitor are already in the tests channel. Otherwise, after the explicit yes (SKILL.md, Ownership):
- Ask which env may be broken; prefer playground. If the component isn't deployed there, the user adds it (and pushes).
- Break the monitor's own condition, not just the component (e.g. scaling to 0 also lowers a `desired` side). Replay the formula at 1m to see the break arrive.
- Managed components (e.g. GKE's Cilium) can't be broken: on the monitor only, set the filter to the test env alone, then lower the threshold below the current value. Never lower it while other envs are in the filter (floods the tests channel).
- Expect detection and recovery of about one window each; don't shorten the window.
- Read the alert and recovery in the tests Slack channel (`believe-alerts-team-sre-tests`): `get-monitor` shows no alert state.
- Every edit of the definition re-notifies its groups and can swallow the recovery (seen). Restore once, don't keep editing to force a recovery; report it as unproven.
- Restore everything you changed and check the component is healthy.

For k8s workloads deployed by ArgoCD (values repo):
- New env folder: copy int's files including the hidden `.argocd-override.yaml` (`ls -a`; the ApplicationSet skips folders without it).
- If ArgoCD would revert the break, disable the app's `syncPolicy.automated` first. Break with `Recreate` + a non-existent image tag.
- Restore: re-enable `automated` (prune, selfHeal) and any field the chart doesn't set (e.g. deployment strategy).
