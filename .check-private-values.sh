#!/bin/sh
# Refuse commits while any tracked file contains a value from the machine-local
# chezmoi data: those belong in chezmoi.toml and reach files through a template.
# Scans every file, so a value added to chezmoi.toml later is caught everywhere.
cfg=${CHEZMOI_CONFIG:-$HOME/.config/chezmoi/chezmoi.toml}
# Public placeholders from 00-defaults.yaml (e.g. "default") are not private.
public=$(sed -n 's/^[^#:]*:[[:space:]]*//p' .chezmoidata/00-defaults.yaml)
values=$(sed -n '/^\[data/,$p' "$cfg" 2>/dev/null | sed 's/[[:space:]]#.*//' \
  | grep -oE '"[^"]{6,}"' | tr -d '"' | sort -u | grep -vxF "$public")
[ -n "$values" ] || exit 0
if printf '%s\n' "$values" | git grep --cached -nF -f -; then
  echo 'Private value(s) above: run "dot -t <file>" and replace them with {{ .key }} from chezmoi.toml.' >&2
  exit 1
fi
