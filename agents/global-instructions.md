# Machine-wide notes for coding agents

Read by Claude Code (`~/.claude/CLAUDE.md`) and Codex (`~/.codex/AGENTS.md`)
on this machine.

## This machine is configured with nix

Packages, shell config, git, ssh and the agent CLIs come from a nix-darwin
and home-manager flake in `~/.dotfiles`, with per-machine values in
`~/.dotfiles-private`. `~/.dotfiles/CLAUDE.md` describes the layout.

- Many files under `$HOME` are symlinks into `/nix/store` and read-only.
  Change the source in `~/.dotfiles` instead of the file itself.
- To make a tool available everywhere, add it to `home.nix` there and have
  the user run `rebuild` (it needs sudo). Don't `brew install` or
  `nix profile install` it. For a one-off, `nix shell nixpkgs#<name>` or
  `nix run nixpkgs#<name>` needs no install.
- A project's own tools come from its `flake.nix`, loaded by direnv from an
  `.envrc` containing `use flake`. If a command a project expects is missing,
  run it as `direnv exec . <command>` or `nix develop -c <command>`.

## Writing code

- Change only what the task needs. Don't reformat, rename or refactor
  nearby code; mention unrelated problems instead of fixing them. Small
  diffs are easier for me to review.
- Read the surrounding code first and follow its conventions. Reuse
  existing helpers rather than writing new ones.
- Write the simplest thing that works. No abstractions, options or
  layers for needs that don't exist yet.
- Let errors surface. Don't catch exceptions you can't handle or add
  fallbacks and defaults that hide a failure; validate only at real
  boundaries (user input, external APIs).
- Write tests from what the code is supposed to do, not from how it
  does it. Assert on behaviour a caller can see (return values, output,
  state, errors) rather than on internal calls, private helpers or the
  exact steps taken, and mock only at real boundaries (network, clock,
  filesystem). Work out expected values from the requirement, not by
  running the code and copying its output. A test that mirrors the
  implementation passes when the code is wrong and breaks when it is
  refactored correctly.
- Before saying something is done, run the project's tests, type
  checker and linter. Don't weaken a test or special-case code to make
  it pass. If something fails or couldn't be run, say so plainly.
- If a request is ambiguous or the approach seems wrong, ask or state
  your assumption before writing a lot of code.
- Comments explain why, not what. Don't leave comments narrating the
  change, dead code, compatibility shims or TODOs.
- Ask before adding a dependency.

## Logging in with the Playwright browser

Credentials for web logins are available to the Playwright MCP browser as
named secrets. You never see their values, and you don't need to.

- Run `playwright-secret-list` to see which names exist. It prints names
  only; there is no command that prints a value.
- To use one, type its name, exactly as listed, as the text of a Playwright
  type or fill action (for example the text `SOME_SERVICE_PASSWORD` into a
  password field). Playwright substitutes the real value as it types.
- In what Playwright reports back, a secret's value appears as
  `<secret>NAME</secret>`.
- Don't read a filled-in secret field back out of the page (with an
  evaluate call, for instance). The masking only matches the exact value,
  so a value that comes back escaped can show up in your output.
- If the secret you need isn't listed, ask the user to add it with
  `playwright-secret-set NAME`. Don't ask them to paste the value into the
  conversation.
- Secrets are loaded when the browser tool starts, so newly added ones need
  a new session.

## Databases are reachable by name with `db`

The databases this machine knows about are described in the private
dotfiles, and `db` reaches them by name; the same descriptions are in
`~/.config/databases.json`. Passwords stay in the Keychain and `db` hands
them to the client, so you never need to see them.

- `db list` shows each database's name, env (`local`, `dev` or `prod`),
  driver and address; `db show NAME` gives one as JSON.
- `db run NAME [ARG...]` opens its client (mysql, psql or sqlite3), with the
  ARGs passed on, e.g. `db run NAME -e 'select ...'`.
- `db exec NAME -- CMD` runs CMD (a test suite, a script) with `DB_HOST`,
  `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_DATABASE` and `DB_URL` set. Don't
  print those values.
- Databases that go through an ssh tunnel have it started for them. If that
  fails, the user probably needs to be on that site's VPN.
- `prod` databases are live. `db run` opens them read-only and `db exec`
  refuses them. Don't pass `--write` to a `prod` database unless the user
  has asked for that specific change. Prefer `local`, then `dev`, for
  anything that writes.

## Sessions run in Emacs agent-shell

The user usually runs agents inside Emacs with agent-shell, often several at
once across projects; `agent-shell-hq` lists them and groups them by project.
This means each project keeps a record of its sessions:

- `<project-dir>/.agent-shell/transcripts/<start-time>.md` holds one Markdown
  transcript per session, named by when it started (e.g.
  `2026-10-15-10-32-49.md`). The header gives the agent, start time, working
  directory and session ID, and the rest is every prompt and every tool call
  with its output.
- `<project-dir>/.agent-shell/screenshots/` holds images the user pasted
  into a session.

When the user asks about another session ("was that in a different
buffer?", "what did the other agent decide?"), search the transcripts in the
relevant project directories rather than guessing. They can be several MB,
so grep for keywords and read only the matching part rather than loading
the whole file. For a Claude session, the session ID in the header is also
the name of its log under `~/.claude/projects/<project-slug>/`.

Transcripts record command output verbatim, including any credentials that
appeared in it. Don't quote secret values from them, and keep `.agent-shell/`
out of commits and out of scanner inputs. In vertebrai it is excluded through
`.git/info/exclude`, so check that a project ignores it before you assume it
does.

## Worktrees go inside the repository

Put a git worktree at `<repo>/.claude/worktrees/<name>`, never beside the
repository (`../<repo>-<branch>`, `../wt-...`). That is where Claude Code's
own worktree tool puts them, so every agent's worktrees for a project are in
one place and `git worktree list` in the repository finds them. Name the
directory after the branch or the task, without a repository prefix.

- `git worktree add .claude/worktrees/<name> -b <branch>` from the
  repository's root; Codex too, despite the directory's name.
- The path is ignored by git everywhere (home.nix), so it never shows as
  untracked.
- When the work is merged or abandoned, remove it with
  `git worktree remove .claude/worktrees/<name>` (and delete the branch if
  it was only for that) rather than leaving it for the user to find.
