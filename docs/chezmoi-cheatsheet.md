# chezmoi cheatsheet

## The mental model

Three states, and every command moves between them:

```
source state          target state           destination state
~/.local/share/       (computed: source  →   ~ (your actual
chezmoi/               + config data)         dotfiles)
   dot_zshrc      ──────────────────────→    ~/.zshrc
        ↑                                          │
        └────────────── re-add / add ──────────────┘
```

`apply` goes right. `add` / `re-add` go left. `diff` and `status` compare.
The config file `~/.config/chezmoi/chezmoi.toml` is the per-machine input that
turns one source state into different target states on different machines.

## Daily loop

| Command | What it does |
|---|---|
| `chezmoi edit --apply ~/.zshrc` | edit the **source**, apply on save. The everyday one. |
| `chezmoi diff` | what `apply` would change. Read this before applying. |
| `chezmoi status` | short form. Col 1 = changed since last apply, col 2 = what apply will do. |
| `chezmoi apply -v` | write target state to `~`. `-n` for a dry run. |
| `chezmoi re-add` | you edited `~/.zshrc` directly — pull it back into the source. |
| `chezmoi update` | `git pull` + `apply`. What you run on your second machine. |
| `chezmoi cd` | shell in the source repo. `exit` to leave. |
| `chezmoi managed` | exactly what chezmoi controls. Run it when unsure. |
| `chezmoi doctor` | environment sanity check. |

`chezmoi -n -v apply` is the safe way to preview anything.

## Adding and removing

```sh
chezmoi add ~/.foo                 # start managing, verbatim
chezmoi add --template ~/.foo      # start managing as a template
chezmoi add --encrypt ~/.foo       # store encrypted (needs age/gpg configured)
chezmoi forget ~/.foo              # stop managing; leaves ~/.foo alone
chezmoi destroy ~/.foo             # stop managing AND delete from ~. Careful.
chezmoi chattr +template ~/.foo    # convert an already-managed file
```

## Source-state naming

The filename in the source dir *is* the configuration. `dot_zshrc` → `~/.zshrc`.

| Prefix | Effect |
|---|---|
| `dot_` | leading dot in the target: `dot_zshrc` → `.zshrc` |
| `private_` | strip group/world permissions (0600 / 0700) |
| `readonly_` | strip write permissions |
| `executable_` | set the executable bit |
| `empty_` | keep the file even when empty (empty targets are removed by default) |
| `create_` | create if missing, then **never** touch the contents again |
| `modify_` | contents are a script: stdin = current file, stdout = new file |
| `exact_` | (dirs) delete anything in the target dir that isn't managed |
| `symlink_` | create a symlink; file contents are the link target |
| `remove_` | remove the target if it exists |
| `external_` | (dirs) ignore attributes in child entries |
| `literal_` | stop parsing further prefixes |
| `run_` | execute as a script on every `apply` |
| `run_once_` | execute once per unique *content* (hash-tracked) |
| `run_onchange_` | execute when the content changes |
| `run_before_` / `run_after_` | order relative to file updates |

| Suffix | Effect |
|---|---|
| `.tmpl` | render as a Go template before writing |
| `.literal` | stop parsing suffixes |

Prefixes stack in a fixed order, e.g. `encrypted_private_dot_ssh/config`,
`run_once_before_00-install.sh.tmpl`.

## Special files

| File | Purpose |
|---|---|
| `.chezmoi.toml.tmpl` | generates the per-machine config; where `promptStringOnce` lives |
| `.chezmoiignore` | targets to skip. **Always a template.** |
| `.chezmoidata/*.yaml` | static data merged into the template context |
| `.chezmoitemplates/` | reusable template fragments, called with `{{ template "name" . }}` |
| `.chezmoiexternal.toml` | files/archives/git repos pulled from URLs |
| `.chezmoiscripts/` | scripts that run without creating a target directory |
| `.chezmoiremove` | targets to delete |
| `.chezmoiversion` | minimum chezmoi version |
| `.chezmoiroot` | relocate the source root |

Files starting with `.` are ignored by chezmoi **except** those starting with `.chezmoi`.

## Templating

```sh
chezmoi data --format=yaml                      # everything available to templates
chezmoi execute-template '{{ .repoRoot }}'      # try an expression
chezmoi execute-template < dot_zshrc.tmpl       # render a whole file
chezmoi cat ~/.gitconfig                        # target contents without writing
```

Built-ins: `.chezmoi.hostname` (up to the first `.`), `.chezmoi.os`, `.chezmoi.arch`,
`.chezmoi.username`, `.chezmoi.homeDir`, `.chezmoi.osRelease`, `.chezmoi.sourceDir`.
Everything under `[data]` in the config is addressed **without** a `data.` prefix.

```
{{ if eq .chezmoi.os "linux" }}...{{ else }}...{{ end }}
{{ if (and (eq .chezmoi.os "linux") .isWork) }}...{{ end }}     # parens required
{{ range .vault.addrs }}{{ . | quote }} {{ end }}
{{ output "kubectl" "config" "current-context" | trim }}        # runs every apply
{{ if lookPath "fzf" }}...{{ end }}
{{- trims whitespace left,  right -}}
```

Templates run with `missingkey=error`, so a typo'd variable fails loudly. Good.

## Three gotchas that bite everyone

1. **`.chezmoiignore` matches target paths, not source names.** Write
   `.oh-my-zsh/custom/40-cloud.zsh`, never `dot_oh-my-zsh/...`.
2. **`chezmoi re-add` silently skips templates.** It refuses to overwrite a `.tmpl`,
   so edits made directly to a templated file in `~` are lost on the next `apply`.
   Use `chezmoi edit` for anything templated.
3. **`chezmoi add --exact --recursive ~/.config/foo` marks all of `~/.config` managed**
   and the next `apply` deletes every unmanaged sibling. Never use `--exact` on a
   directory you only partly manage.

## Recovering

```sh
chezmoi state delete-bucket --bucket=scriptState   # let run_once_ scripts run again
chezmoi state delete-bucket --bucket=entryState    # reset run_onchange_ tracking
chezmoi merge ~/.zshrc                             # 3-way merge on a conflict
chezmoi source-path ~/.zshrc                       # which source file backs this target
```

## Exercises

Each is reversible; run them in order.

1. `chezmoi status` then `chezmoi managed` — read the state, change nothing.
2. `chezmoi edit ~/.oh-my-zsh/custom/10-alias.zsh`, add an alias, then `chezmoi diff`,
   then `chezmoi apply -v`. Note that `edit` opened the *source*, not `~`.
3. Now edit `~/.oh-my-zsh/custom/10-alias.zsh` directly and run `chezmoi re-add`.
   Then try the same on `40-cloud.zsh` (a template) and watch it decline.
4. `chezmoi execute-template '{{ .repoRoot }} on {{ .chezmoi.hostname }}'`.
5. `chezmoi chattr +template ~/.vault`, look at the source filename, then `-- -template`.
6. `chezmoi forget ~/.vault`, confirm `~/.vault` still exists, then `chezmoi add ~/.vault`.
7. `chezmoi cd`, `git log --oneline`, `exit`.
