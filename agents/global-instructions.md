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
