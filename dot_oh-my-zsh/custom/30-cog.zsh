# cog (cocogitto) completions.
if (( ! $+commands[cog] )); then
  return
fi

# If the completion file doesn't exist yet, we need to autoload it and
# bind it to `cog`. Otherwise, compinit will have already done that.
if [[ ! -f "$ZSH_CACHE_DIR/completions/_cog" ]]; then
  typeset -g -A _comps
  autoload -Uz _cog
  _comps[cog]=_cog
fi

# Generate and load cog completion
cog generate-completions zsh >| "$ZSH_CACHE_DIR/completions/_cog" &|
