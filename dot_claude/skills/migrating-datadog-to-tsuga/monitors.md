# Monitor rules

Audit every field against the Datadog original: name, message, query, thresholds, window, no-data behavior, alert logic, priority, tags, routing.

## Scope
- **Per-env copies → one monitor** when they differ only by env filter: filter on exactly the envs the copies covered (e.g. `context.env:(int OR sta OR prd OR shd)`), `context.env` in groupBy. Keep prd separate if it needs different thresholds or routing.
- Region like env: not in the name, no `region` tag; the alert group (e.g. cluster name) carries it.
- DD drafts were imported live ("monitor was a draft in Datadog" in migration notes): decide keep or delete, don't leave them firing by accident.
- DD monitors muted (`muted_until_ts` set) never notified: going live in Tsuga is new noise. Report it and ask keep or drop. Downtimes aren't visible with the read-only Datadog tools: ask the user.
- Exclude envs where the component doesn't run instead of keeping a monitor that never has data.
- Drop monitors that can't realistically fire or always fire (SKILL.md, Ownership boundaries: say why, ask, save the JSON).
- Group by the real unit of failure (e.g. per leader-election lease, not summed across leases).

## Name
- No template variables in the name: the notification adds the group values on its own line.
- `[ENV]` prefix only when the monitor genuinely exists per env.
- Otherwise start with the product as plain words, no brackets; avoid ambiguous bare acronyms.

## Message
- Tsuga syntax only `{{ variable }}` (full list: threshold monitor doc). Useful: `alert_status`, `alert_transition`, `alert_triggered_by` (grouped monitors only), `alert_values[0]`, `alert_thresholds[0]`, `alert_timeframe`, `alert_data_url`, `monitor_url`, `dashboard_url`. Unknown variables render literally. No rounding filter works.
- Remove `{{#is_alert}}`, `{{/is_alert}}`, `{{!-- --}}`, `{{x.name}}`, `@` handles, Datadog links, false "managed by Terraform" notes, "Migration notes". A DD notebook runbook link goes with them: report that the runbook needs porting.
- One message for alert, no-data and recovery: state-neutral wording plus `{{ alert_transition }}` (it renders as `from unknown to alert` on a first firing).
- Fix DD copy/paste errors.

## Mapping Datadog settings
- Multi alert → groupBy + alert logic "for each matching value"; simple alert → "if any match".
- No-data: `alert` only if DD had `notify_no_data:true` AND the 7d replay has no gap longer than 2x the window (silence means outage); otherwise `resolve`, and list that monitor in the report (coverage change). Never `alert` on an error/exception/pressure metric (Query).
- Warning / recovery thresholds, OR-composites, custom eval frequency: no direct equivalent. Split, or report what is lost.
- Renotify lives on the notification rule's destination, not the monitor.
- Anomaly on a continuous metric → anomaly detection monitor; on a binary/state metric → plain threshold. Forecast → threshold or report as dropped.

## Query
- Check the data shape first: count samples per series per minute over 1h. Duplicated exporter samples inflate `sum`; ingestion lag makes a windowed `sum` undercount. For gauges, prefer a ratio of two `sum`s over the same data (sample interval and duplicates cancel). `average` with a per-interval threshold (DD `sum(last_Nm)` threshold ÷ number of samples in N) embeds the sample interval: read it from the scrape config, say so in the report, and avoid it when a ratio works, since it breaks silently when the interval changes. Never for log/span counts.
- A DD `== N` on a difference rarely means "exactly N missing": check the intent, prefer `>` with a threshold that survives one missed sample, check against the 7d replay.
- Averaging across series dilutes one real backlog: use `max` when one bad series matters.
- Don't copy a DD `evaluation_delay` as `time-offset` unless Tsuga data lags. No `fill: zero` on lagging metrics.
- Ratio monitors: a counter with no errors may have no series. That means no errors: use `noDataBehavior: resolve` so a stale alert clears.
- **Thresholds**: compare each DD threshold with 7d real values per env. Units change (DD `container.cpu.usage` nanocores, Tsuga cores: `4e9` → `4`). Retuning is fine (keep the intent, replay clean, list each change as old/new/why in the report); on a monitor already `validated:true`, only after the user's go-ahead.
- **Counters**: DD `avg:` averages across series (per-pod mean) and over time; a Tsuga `sum` across pods is not the same. Query both in Datadog (`avg:` vs `sum:`, same grouping, 5m buckets) to see the scale and whether the threshold ever fired, then choose. Never write "equivalent" without that check.
- **Histograms**: DD `.bucket`/`.sum` averages are meaningless: use `percentile` (e.g. p95). `count` on a histogram counts observations (e.g. `return_code:429`).
- **No data on an error/exception/pressure metric means healthy** (no 5xx series, no 429, a metric emitted only above a utilization floor): report it as expected, never as dead, never make it alert, say it can't be replayed. If data appears, that is the issue.
- **Headroom**: a threshold far above the 7d max (rule of thumb: max under 20% of it) doesn't fire on the data. Propose about 2-3x the max and update the number in the message; on a monitor already `validated:true`, report and wait for the user's go-ahead. Idle envs (max 0) say nothing: don't retune on them.
- **Avg to `max`**: replay it first and count episodes. On in-flight/unfinished-work gauges (a sum over items) it can fire dozens of times a week: keep the average and report it.
- **Gauge depth vs lag**: a constant plateau with nothing in flight is not a backlog. Alert on a lag signal (queue wait p99); if the user allows read-only access, confirm on the live system (`kubectl get --raw` pod metrics, lease holder, resource counts).
- **Borderline monitors** (a few firings a week just above the threshold): read the log lines behind them first. A benign cause is fixed by narrowing the filter, not by raising the number.
- **Near-full gauges**: check peak vs average, then the rolling minimum per node (10m buckets) and impact (drops, log errors). If it never stays high and nothing breaks, the peaks are one-sample spikes: no monitor.
- **`== 0` conditions** on traffic clear on residual bytes while the link is still down: compare the hourly average in a real outage with normal values and use a small threshold.
- **Non-prod schedules**: ArgoCD sync windows deny syncs on int/sta/playground nights and weekends (`argocd-gcp-argo-apps`), and `offhours-shutdown` shuts non-prod resources down (its README and policies say which envs). Replay across a weekend; scope to prd/shd or expect the noise.
- Replay: 1-2m buckets over 7d (saved file; if the server times out, narrow the filter or shorten the range before coarsening the buckets), rolling window in `python3 -I`, count firing episodes per group. Report how often it fires.
- Logs/spans: Tsuga query syntax, not DD: no `-field` (use `NOT`), uppercase `AND`/`OR`/`NOT`, uppercase levels (`level:ERROR`), no `@` attribute prefix, span `duration` in ms. DD `trace.*` metrics → span metrics or a trace monitor.

## Tags and routing
- Keep `team`, `service`, `origin-id` (DD id), `validated`, plus meaningful ones (`env` when per-env).
- Drop import tags: `source`, `origin`, `context`, `migration-status`, false `managed_by:terraform`.
- Priority: keep the DD priority unless clearly wrong; imported priorities don't reflect paging.
- `owner`/`permissions`: keep the import's; if the owner isn't the service's team, ask the user once.
- `oncall:true` only for monitors whose DD version paged. Read the handles from the DD monitor, then ask the user once, up front, which of them page; don't infer it from handle names. Tag it even when no paging rule is active (check `list-notification-rules`), and list the tagged monitors in the report: unrouted paging blocks deleting the DD original. If only some envs paged, the paging rule must filter on them (e.g. `context.env:(prd OR shd)`; the user sets it), or keep those envs as their own monitor if the rule can't filter on env. Unverified whether a rule can match alert-group attributes: read the rule or ask.
- Routing is by notification rules, not `@` handles (check `list-notification-rules`): `NOT validated:true` → tests channel, `validated:true` → team channel, `validated:true AND oncall:true` → paging (user activates).

## Live test (replay can't prove alert + recovery)
Skip it if a real alert and recovery of this monitor are already in the tests channel (they count only if they postdate its last edit and match its monitor id), or if the user declined (list it as unproven, don't propose it again). Otherwise, after the explicit yes (SKILL.md, Ownership boundaries), test on a temporary clone of the monitor (`validated:review`, so it alerts in the tests channel, tagged `live-test:<ticket>`; delete it afterwards, and list that tag at the start and end to catch leftovers). Never edit the real monitor:
- If you break something, ask which env may be broken; prefer playground. If the component isn't deployed there, the user adds it (and pushes).
- When breaking, break the monitor's own condition, not just the component (e.g. scaling to 0 also lowers a `desired` side). Replay the formula at 1m to see the break arrive.
- No break needed, or the component can't be broken (managed, e.g. GKE's Cilium; or the signal already exists): change nothing on the cluster. On the clone, set the filter to the test env alone if needed, then lower the threshold below the current value.
- Don't shorten the window (detection took about 2 minutes on a 15-30m window).
- Read the alert and recovery in the tests Slack channel (`believe-alerts-team-sre-tests`): `get-monitor` shows no alert state. The channel is busy: bound `slack_read_channel` with `oldest` and `latest` and match the monitor id.
- Every edit of the clone's definition re-notifies its groups and can swallow the recovery (no recovery seen after 17-24 min in two tests): edit once, don't keep editing to force a recovery; after one window report it as unproven, don't wait longer.
- Delete the clone, restore everything you changed on the component and check it is healthy.

For k8s workloads deployed by ArgoCD (values repo; `git status` first, never commit or push):
- New env folder: copy int's files including the hidden `.argocd-override.yaml` (`ls -a`; the ApplicationSet skips folders without it).
- If ArgoCD would revert the break, disable the app's `syncPolicy.automated` first. Break with `Recreate` + a non-existent image tag.
- Restore: re-enable `automated` (prune, selfHeal) and any field the chart doesn't set (e.g. deployment strategy).
