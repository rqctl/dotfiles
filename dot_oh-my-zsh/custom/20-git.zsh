# ----- GIT -----

alias gd='git diff'
alias gdr='gitdrift'
alias lg='lazygit'
alias gpfnoci='git push --force-with-lease --force-if-includes -o ci.skip'
alias gpwd='git rev-parse --show-toplevel 2>/dev/null || echo .'
alias cdr='cd $(gpwd)'
alias gpc='git pull && git fetch -pPf && for branch in $(git branch -vv | grep ": gone]" | awk '\''{print $1}'\''); do git branch -D $branch; done;'
alias gamend='git add $(gpwd) && git commit --amend --no-edit && git push --force-with-lease;'
alias gamendnoci='git add $(gpwd) && git commit --amend --no-edit && git push --force-with-lease -o ci.skip;'
alias gps='git pull --autostash'
alias gotoc='open $(echo $(git remote get-url origin | sed -E "s#^(git@([^:]+):|https://([^/]+)/)#https://\2\3/#; s/\.git$//")/-/commit/$(git rev-parse @{u})) &>/dev/null &'
alias gdiff='(git --no-pager diff --name-only --diff-filter=d --merge-base $(_git_default_branch) -- ; git ls-files --full-name --others --exclude-standard :/) | sort -fu'
alias gdiffhuman='(git --no-pager diff --name-status --merge-base $(_git_default_branch) -- ; git ls-files --full-name --others --exclude-standard :/ | sed "s/^/??  /") | sort -fu | column -t'


# Echoes "<remote>/<branch>", cheapest source first; the network lookup is cached.
_git_default_branch() {
    command git rev-parse --git-dir &>/dev/null || return

    local ref
    ref=$(command git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null) \
        || ref=$(command git symbolic-ref refs/remotes/upstream/HEAD 2>/dev/null)
    if [[ -n "$ref" ]]; then
        echo "${ref#refs/remotes/}"
        return 0
    fi

    ref=$(command git remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p')
    [[ -z "$ref" ]] && return 1
    command git remote set-head origin "$ref" 2>/dev/null
    echo "origin/$ref"
}

# prek exits non-zero both when a hook auto-fixes files and when one fails, so
# re-stage and retry once: a second failure is real.
_prek_stage_and_run() {
    git add . || return 1
    prek run --files $(gdiff) && return 0
    git add .
    prek run --files $(gdiff)
}

# --git-path resolves the shared hooks dir; in a worktree .git is a file, so
# $(gpwd)/.git/hooks/... never matches.
_prek_installed() {
    [[ -f "$(git rev-parse --git-path hooks/pre-commit)" ]] || prek install
}

# Usage: _branch_exists <branch> — known locally or on origin.
_branch_exists() {
    local branch=$1
    git show-ref --verify --quiet "refs/heads/$branch" \
        || git ls-remote --exit-code --heads origin "$branch" &>/dev/null
}

# Usage: _commit_push_mr <branch> <commit> <category>
_commit_push_mr() {
    local branch=$1 commit_msg="$2" category=$3
    git add . && git commit -m "$commit_msg" && git push -u origin "$branch" && _glab_mr_create "$category"
}

# Usage: pcr — run the prek hooks on everything that differs from the default branch.
pcr() {
    ( cd "$(gpwd)" || return 1
      _prek_installed
      local -a files
      files=(${(f)"$(gdiff)"})
      if (( ${#files} == 0 )); then
          echo 'No diff'
      else
          echo "Updated files:"
          gdiffhuman
          echo
          prek run --files $files
      fi )
}

# Usage: gitacp [-n] <subject> [body] — pull, add, commit and push in one go.
# -n allows repos without a prek config.
gitacp() {
    local opt OPTIND=1 PREK_ALLOW_NO_CONFIG
    while getopts "n" opt; do
        case $opt in
            n) PREK_ALLOW_NO_CONFIG=1; export PREK_ALLOW_NO_CONFIG ;;
            *) echo "Usage: gitacp [-n] <subject> [body]"; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))
    [[ -z "$1" ]] && { echo "Usage: gitacp [-n] <subject> [body]"; return 1; }

    ( cd "$(gpwd)" || return 1
      _prek_installed
      gps && git add . && git commit -m "$1" ${2:+-m "$2"} && git push )
}

gitacp2() {
    gitacp -n "$@"
}

# Usage: _git_category_prompt — asks for an MR category when none was given.
# Empty input (just Enter) confirms no label; ship/show/ask sets one.
# Callers capture this via $(...), so prompts/errors must go to stderr —
# anything written to stdout would be swallowed into the captured value.
_git_category_prompt() {
    local -a valid=(ship show ask)
    local category
    while true; do
        printf '\n❓ No category given -- no labels will be created. Press Enter to confirm, or enter one of ship/show/ask: ' >&2
        read -r category
        [[ -z "$category" ]] && return 0
        if (( ${valid[(Ie)$category]} )); then
            echo "$category"
            return 0
        fi
        echo "Invalid category '$category' -- must be one of: ship show ask" >&2
    done
}

# Usage: _glab_mr_create [ship|show|ask] — draft MR; category (if any) applied as a label.
# No category prompts for one; empty answer means no labels.
# --fill would overwrite the description and lose the repo's MR template.
_glab_mr_create() {
    local category="$1"
    [[ -z "$category" ]] && category=$(_git_category_prompt)
    local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    local -a label_args
    [[ -n "$category" ]] && label_args=(--label "sre-review::${category}")
    if [[ -f "$repo_root/.gitlab/merge_request_templates/Default.md" ]]; then
        glab mr create -a @me --title "$(git log -1 --pretty=%s)" --template Default "${label_args[@]}" --draft --yes
    else
        glab mr create -a @me --fill "${label_args[@]}" --draft --yes
    fi
}

# Usage: gmr2 [ship|show|ask] — push the current branch as is and open its MR.
gmr2() {
    git push -u origin "$(git branch --show-current)" && _glab_mr_create "$1"
}

# Usage: gmr <branch> <commit_msg> [ship|show|ask] — branch, prek, commit in $EDITOR, draft MR.
gmr() {
    local branch="$1" commit_msg="$2" category="$3"
    [[ -z "$branch" ]] && { echo "Usage: gmr <branch> <commit_msg> [ship|show|ask]"; return 1; }

    ( cd "$(gpwd)" || return 1
      if _branch_exists "$branch"; then
          echo "Branch '$branch' already exists locally or remotely."
          _confirm "Proceed anyways ?" || return 1
          git checkout "$branch" || return 1
      else
          git checkout -b "$branch" || return 1
      fi

      _prek_stage_and_run || {
          echo "prek hooks failed — aborting before commit (still on branch '$branch')."
          return 1
      }
      _commit_push_mr "$branch" "$commit_msg" "$category" )
}

# Usage: gsbranch — fzf-pick a local branch, check it out and fetch.
gsbranch() {
    local preview_command='git branch --list {} -vv --color=always; echo -e "\n" ; git log -10 --color=always --decorate --pretty="format:%C(yellow)%h%Creset %C(blue)(%cr)%Creset %s %C(green)%d%Creset" {}'
    local branch_list=$(git branch --format='%(refname:short)')
    [[ -z $branch_list ]] && return 1
    if branch=$(echo $branch_list | fzf -1 -e -i --preview-window=70% --preview="$preview_command"); then
        git checkout $branch
        git fetch
    fi
}

# Usage: grenamebranch <old> <new> [ship|show|ask]
grenamebranch() {
    local old="$1" new="$2" category="$3"
    [[ -z "$old" || -z "$new" ]] && { echo "Usage: grenamebranch <old> <new> [ship|show|ask]"; return 1; }

    git fetch -p || return 1
    git checkout "$old" || return 1
    git pull || return 1
    git branch -m "$old" "$new" || return 1
    # A protected old branch cannot be deleted; the new one is still worth pushing.
    git push origin --delete "$old" \
        || echo "Warning: could not delete origin/$old — remove it by hand."
    git branch --unset-upstream "$new" 2>/dev/null
    git push origin -u "$new" && _glab_mr_create "$category"
}
