#!/usr/bin/env python3
"""Warn when an edit adds a run of 3+ consecutive comment lines (CLAUDE.md: 1-2 lines)."""
import json, re, sys

SKIP_EXT = {'.md', '.markdown', '.mdx', '.txt', '.rst', '.json', '.lock', '.csv'}
COMMENT = re.compile(r'^\s*(#|//|--|;;)')
SHEBANG = re.compile(r'^\s*#!')
MAX_RUN = 2


def added_text(data):
    ti = data.get('tool_input') or {}
    parts = []
    if isinstance(ti.get('content'), str):
        parts.append(ti['content'])
    if isinstance(ti.get('new_string'), str):
        parts.append(ti['new_string'])
    for e in ti.get('edits') or []:
        if isinstance(e, dict) and isinstance(e.get('new_string'), str):
            parts.append(e['new_string'])
    return parts


def longest_run(text):
    best = run = 0
    snippet = []
    cur = []
    for line in text.split('\n'):
        if COMMENT.match(line) and not SHEBANG.match(line):
            run += 1
            cur.append(line.strip())
            if run > best:
                best, snippet = run, list(cur)
        else:
            run, cur = 0, []
    return best, snippet


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    path = (data.get('tool_response') or {}).get('filePath') \
        or (data.get('tool_input') or {}).get('file_path') or ''
    if any(path.lower().endswith(e) for e in SKIP_EXT):
        return
    worst, snippet = 0, []
    for text in added_text(data):
        n, s = longest_run(text)
        if n > worst:
            worst, snippet = n, s
    if worst <= MAX_RUN:
        return
    preview = '\n'.join(snippet[:6])
    msg = (f"Comment block of {worst} lines added to {path or 'file'} "
           f"(CLAUDE.md limit: 1-2 lines).")
    print(json.dumps({
        "systemMessage": msg,
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": (
                f"{msg} Trim it to the constraint only - drop anything that narrates the "
                f"change, an incident, a measurement, or a decision. Block added:\n{preview}"
            ),
        },
    }))


main()
