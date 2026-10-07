# opencode.nvim — agent guide

## What it is

A Neovim Lua plugin that bridges Neovim and the `opencode` CLI (external binary). It discovers or starts an `opencode` server, communicates via REST + SSE, and provides UI for prompting, context injection, session management, and edit review.

## Entrypoints

- **Public API**: `lua/opencode.lua` — exports `ask()`, `select()`, `prompt()`, `command()`, `operator()`, `format()`, `statusline`, `pick_session()`, `clear_session()`
- **User command**: `plugin/opencode.lua` registers `:OpencodeSession` (opens the session picker, pins the choice; `+ New session` entry creates one; `--clear` unpins back to follow-latest)
- **Config**: `vim.g.opencode_opts` global (not a `setup()` call); merged with defaults from `lua/opencode/config.lua`
- **Plugin files**: `plugin/highlights.lua` sets highlight groups; `plugin/events/` registers four autocmd groups (`OpencodeReload`, `OpencodeStatus`, `OpencodePermissions`, `OpencodeEdits`) that listen for `OpencodeEvent:*` User events to reload edited buffers, update statusline, display permission requests, and diff edit proposals

## Config quirks

- Config is passed via `vim.g.opencode_opts` for simpler UX and faster startup (see `lua/opencode/config.lua:6`)
- `snacks.nvim` nested opts go under `ask.snacks` / `select.snacks`, then get merged into the passed options at usage time (`lua/opencode/ui/ask/init.lua`, `lua/opencode/ui/select.lua`)
- `vim.o.autoread` is automatically set to `true` when `events.reload.enabled = true` (the default) unless the user has explicitly configured it
- Neovim doesn't support mixed integer/string keys in `vim.g`, which affects some `snacks.input` options; workaround: modify `require("opencode.config").opts` directly

## Dependencies

- **Required**: `opencode` CLI, `curl`
- **Auto-discovery**: reads OpenCode's background service registration (`service.json`) from its state directory (unless `server.url` is set)
- **Optional**: `snacks.nvim` (enhances `ask()` with `snacks.input`, `select()` with `snacks.picker`), `blink.cmp` (completion plugin with LSP source)
- No hard Lua dependencies beyond Neovim itself

## Verification commands

```bash
# Type-check (requires neovim + lua-language-server + cloned snacks/blink)
lua-language-server --configpath .luarc.ci.json --check=.

# Format check
stylua --check .

# Format in place
stylua .
```

## CI

- **`.github/workflows/lua-ls.yml`**: type-check on push/PR to main
- **`.github/workflows/stylua.yml`**: format check on push/PR to main
- **`.github/workflows/release-please.yml`**: automated releases via release-please (non-fork, main branch only)

## Testing

- No test framework — no tests directory, no test runner config
- Manual verification: `:checkhealth opencode`

## Formatting (StyLua)

- `column_width = 120`, `indent_width = 2`, spaces, double quotes, no call parentheses
- File: `.stylua.toml`

## Type-checking (LuaLS)

- Config: `.luarc.ci.json`
- Runtime: `LuaJIT`
- Library paths: `/opt/nvim/share/nvim/runtime/lua`, cloned `snacks.nvim` and `blink.cmp`

## Architecture notes

- **Async**: custom Promise implementation in `lua/opencode/promise/init.lua` (fork of `promise.nvim`)
- **Server discovery flow** (`lua/opencode/server/discovery/init.lua`): connected server → configured URL → OpenCode background service registration (`service.json`, URL + password) → auto-start + poll (5s timeout)
- **OpenCode v2 API** (`lua/opencode/server/init.lua`): the HTTP API lives under `/api/*` and requires HTTP basic auth. The password comes from the service registration or `opts.server.password`. Requests carry `x-opencode-directory: <nvim cwd>`; the daemon is shared across projects, so `/api/session` is scoped with a `directory` query. Prompts and commands target the pinned session (set via `Server.set_pinned()`, the single pin mutation point — it also refreshes the statusline, which shows the pin as lock glyph + title) if one is live for Neovim's directory, else the most recently updated root session (`Server:resolve_session()`), resolved per call and never cached; an expired pin is cleared, warned, and re-picked inline. `Server:create_session()` posts to `/api/session` with `location.directory` scoping (the daemon is shared across projects). OpenCode v2 has no TUI-driving or prompt-append API.
- **Discovery vs connection**: server.connect (default true) controls whether the discovered server is automatically subscribed to via SSE. When false, the server is found but not connected.
- **Context system** (`lua/opencode/context/init.lua`): captures buffer/win/cursor/selection before UI opens, renders placeholders (`@this`, `@buffer`, etc.) in prompts
- **Events**: SSE subscribed on `connect()` (`/api/event`), dispatched as `OpencodeEvent:<type>` User autocmds. OpenCode v2 events are shaped `{ id, type, data }`.
- **Edit review**: opens diff in new tab via `:diffpatch`, keymaps `da`/`dr` to accept/reject, `dp`/`do` for per-hunk
- **Ask completion**: in-process LSP server (`lua/opencode/ui/ask/cmp.lua`) providing context placeholder + agent completions
- **Integration policy**: code that bridges another tool _to_ opencode.nvim (e.g. picker send, terminal toggle) belongs in README examples. Code that enhances opencode.nvim's own UI (ask/select with snacks input/picker) stays in the plugin.
- **Operator**: `operator()` sets `operatorfunc`, uses `g@` for range + dot-repeat support

## Project vision

See [CONTRIBUTING.md](./CONTRIBUTING.md) for project guidelines, priorities, and maintenance philosophy. When in doubt, follow the patterns already in the codebase.

<!-- epic-tasks:begin (managed by epic_bootstrap.py; updates print a diff, never rewrite) -->
## Epic-tasks tracking rules

- **Repo layout convention:** everything epic-tasks creates lives in
  `.epic-tasks/` — capture ledger at `.epic-tasks/INBOX.md`, conventions at
  `.epic-tasks/epics.yaml`, each epic as a dir
  `.epic-tasks/<epic-name>/` (`epic.md` + `taskN.md`, optional
  `design.md`), loose tasks in `.epic-tasks/backlogs/`, done epics in
  `.epic-tasks/archived/`.
- **Capture:** the moment the user states a request/bug/story, append ONE
  line to `.epic-tasks/INBOX.md` (date · one line · source · status
  `new`). Fast, lossless; triage later.
- **Track before shipping:** no implementation before the task row/files
  exist and the user approved them. No untracked commits.
- **Done = gate green:** a task is done only when the `gate` command from
  `.epic-tasks/epics.yaml` passes AND the commit hash is recorded.
- **Tick on completion:** status + commit hash updated in the same commit as
  the work; docs sync (`docs_sync`) in that commit too.
- **Progression:** a task that spans a session or gets non-trivial is
  promoted to `taskN.md` in its epic dir (story + DoD checklist + `## Work
  log`); demotion never happens.
- **Status view:** to report progress run
  `python3 .opencode/skills/epic-tasks/epic_status.py <repo>` (table;
  `--json` · `--watch` · `--html`) — don't read tracking docs to summarize.
- **Workflow owner:** `.opencode/skills/epic-tasks/` (installed from
  skill_factory — see `.installed-from` in that folder).
<!-- epic-tasks:end -->

<!-- epic-tasks:tmux:begin (managed by epic_bootstrap.py; updates print a diff, never rewrite) -->
## tmux background shell convention (agent shell work)

Run shell/background tasks inside a tmux session (not the harness background shell), with a
**`opencode-` prefixed name** so they're recognisably the agent's and can't clash with the user's
sessions (`opencode-p1`, `opencode-gate`, …). Launch the command IN THE PANE (so the user can
`tmux attach -t opencode-<name>` and watch it live) and tee it to a log with `pipe-pane`
(create `.tmp/` in the repo on first use):

```
tmux new -d -s opencode-<name> -c <dir>
tmux pipe-pane -t opencode-<name> -o 'cat >> <dir>/.tmp/<name>.log'
tmux send-keys -t opencode-<name> 'cmd; echo DONE=$?' C-m
```

The pane keeps a prompt after the command ends — completion = `DONE=<digit>` in the log (the
typed command line also contains `DONE=$?`, so match a digit). **Never redirect the pane
command's output to a file** (`cmd > x.out 2>&1` silences the pane, defeating attach-to-watch) —
pipe-pane's tee IS the log; run `cmd` bare in the pane so stdout is visible to an attached user
AND recorded in `.tmp/<name>.log`.

**Efficiency pattern — separate launch from wait:**
- Launch (tmux new + pipe-pane + send-keys) is one quick FOREGROUND call.
- Chain dependent steps IN THE send-keys (`build && spec; echo DONE=$?`) so a logical unit emits
  ONE `DONE` signal — one notification, no re-round-trips.
- The completion waiter is an explicit BACKGROUND shell call, ALWAYS BOUNDED
  (`i=0; until grep -qE 'DONE=[0-9]' log || [ $i -ge 120 ]; do sleep 10; i=$((i+1)); done;
  grep summary || echo NO_DONE`), NOT a foreground blocking loop. Size the bound to the expected
  gate length (e.g. 120 × 10 s for a ~3-min gate).
- **The waiter is a convenience notification, never the source of truth:** the log is. On ANY
  session resume with a missing/late notification, FIRST check the log
  (`grep -E 'DONE=[0-9]' .tmp/<name>.log`) and the pane (`tmux capture-pane`) — if DONE is
  present, the task finished; proceed. Never block on the notification.
- While the waiter runs, do non-conflicting work (docs ticks, work logs, next task's scouting);
  parallel independent units get parallel `opencode-` sessions — don't serialize what doesn't
  depend.
- Observe without attaching: `tmux capture-pane -p -t opencode-<name> | tail`.
- Clean up: `tmux kill-session -t opencode-<name>` in the SAME call as launching the replacement
  (keeps the tree clean, no port squatters); then self-safe `pkill` for leftovers in a SEPARATE
  shell call, so the kill patterns can't match that call's own argv. A system reboot kills all
  tmux sessions — the `.tmp/` log (pipe-pane tee) is the surviving record; after a reboot, check
  the log for `DONE=<digit>` before re-running anything.
<!-- epic-tasks:tmux:end -->
