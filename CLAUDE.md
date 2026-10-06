# CLAUDE.md

@AGENTS.md

## Claude-Specific Notes

- A PreToolUse hook actively blocks the raw equivalents of several read-only operations covered by `sak` — prefer `sak` as directed in AGENTS.md.
- Raw `git` reads (`status`, `log`, `diff`, `show`, `blame`) are hook-blocked; use `sak git` instead. Raw `git` is still required for mutations (`commit`, `push`, `add`, etc.) — the hook only blocks read-only git verbs.
- The built-in Read/Glob/Grep tools remain the right call for plain file reads — reach for `sak fs` only for what those don't cover (`largest`, `duplicates`, `find`, `tree`, `stat`, `wc`).
