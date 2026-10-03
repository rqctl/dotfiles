# Writing for humans (MR/PR descriptions, commit messages, docs)

Humans read these. Be concise, always. Lead with what changed and why it's
safe/needed — a few lines, not a report.

- If a description needs that much text to explain, that's a signal the
  change itself needs splitting or rethinking, not a signal to write more.
- Cut background/investigation narrative, verification checklists, and
  restating context the reviewer already has. Link an issue/ticket instead
  of re-explaining it inline.
- Prefer: what changed, why, anything risky/non-obvious. Nothing else.

# Code comments

Write comments a maintainer would keep, not a narration of my work.

- No comments explaining what I just changed, why I chose an approach, or that
  something was refactored/added/fixed. That belongs in the commit message or
  the chat, never in the code.
- Comment only subtle or non-obvious code: a workaround and the constraint
  forcing it, a non-obvious invariant, a unit/ordering/edge case, a link to a
  ticket or upstream bug.
- Keep them short — one or two lines. If it needs a paragraph, the code needs
  restructuring or a clearer name instead.
- Never restate what the code already says.
- Test before writing one: if it only makes sense to someone who watched the
  debugging, delete it. A constraint is what the code must satisfy now; a
  finding is what I learned getting there. Only the constraint stays.

# Debugging a broken Terraform/Terragrunt stack or unit

When a `terragrunt plan`/`apply` fails (data-source lookup errors, auth
errors, provider errors), don't guess at the fix from the error text alone —
reproduce it live and bisect down to the real root cause before editing code.

- Re-auth first if the shell reports missing/expired credentials (e.g. Vault
  401/403). Shell state (env vars) does NOT persist between Bash tool calls,
  so chain the login and the terragrunt command in the *same* Bash call, or
  it'll be gone by the next one (`login_vault -ra && terragrunt run -- plan`).
- Reproduce with `terragrunt run -- plan` (terragrunt's CLI wraps commands
  behind `run --`; unknown-command errors mean you forgot `run --`).
- If a value looks wrong/missing (e.g. a map lookup failing), don't assume
  the hardcoded value is stale — check for non-determinism first: run the
  same lookup via `terragrunt run -- console` a few times and compare against
  a real `plan` run. `console` may show a *stale* cached value from state
  (data sources aren't always freshly re-read), while `plan` always re-reads
  data sources — so a mismatch between the two is a signal, not proof of
  flakiness either way. Add a temporary `output` block (e.g.
  `setsubtract(list, keys(map))`) in the stack to print the exact diff in a
  real plan, then delete it once you have the answer — don't leave debug
  scaffolding committed.
- Before touching provider-version pins: check if a comment references a
  known upstream GitHub issue/bug — the pin may be intentionally frozen
  pending a fix. Confirm with the user before bumping it, and re-test with a
  clean provider cache (`rm -rf .terragrunt-cache`, `terragrunt run -- init
  -upgrade`) so the new version is actually exercised.
- For an "Invalid index"-style missing-key error against a live API-backed
  data source (e.g. Cloudflare permission groups), the API may have simply
  renamed/removed the value — grep the fresh key list for near-matches
  (`strcontains(lower(k), "...")`) before assuming corruption.
- For Vault auth errors on an aliased/secondary `provider "vault"` block
  (multi-cluster stacks): check `add_address_to_env` on that provider block
  against the default one in `root.hcl`. If a custom multi-address Vault
  token helper is in play (keyed off `$VAULT_ADDR`, e.g. a `login_vault`/
  `_vault_login` zsh function backed by `vault-token-helper`), a provider
  alias with `add_address_to_env = false` won't export its own address, so
  the helper resolves the token cached for whatever address the *other*
  provider last set — silently handing the wrong cluster's token. Setting it
  `true` (matching the default provider) fixes this without any custom
  hook/token-file plumbing.
- Never delete/rename resources or yaml entries backing already-applied
  state to "fix" an error — check `terragrunt run -- state list` first; if
  the resource already exists, the fix must preserve it (auth/config fix),
  not destroy-and-recreate.
- Always clean up temporary debug `output` blocks/files and verify with 2-3
  repeated `plan` runs before declaring the fix durable (rules out both
  transient auth flakes and a fix that only worked by accident once).
- Never run destructive terragrunt command.

# Git

Never run `git push` (including `--force`/`--force-with-lease`) on my behalf,
on any branch. Commit freely, but leave pushing to me.

- Never `git checkout -B <branch> origin/<other-branch>` (or any equivalent
  that resets a branch from a *different* remote ref) to rebuild/reset a
  branch's content. Besides resetting content, it silently resets the
  branch's upstream tracking to that other remote ref (e.g. `origin/main`),
  so a later plain `git push` would push onto the wrong branch.
- To reset a branch's content from another ref without touching tracking:
  `git checkout <branch>` first, then `git reset --hard <other-ref>` (keeps
  the branch's own existing upstream). If tracking did get changed, fix it
  with `git branch --set-upstream-to=origin/<correct-branch>` immediately.
