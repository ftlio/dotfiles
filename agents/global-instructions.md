# Machine-wide notes for coding agents

Read by Claude Code (`~/.claude/CLAUDE.md`) and Codex (`~/.codex/AGENTS.md`)
on this machine.

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
