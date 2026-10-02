# dotfiles

macOS configuration as a nix flake: [nix-darwin] for the system,
[home-manager] for everything under `$HOME`.

- `darwin.nix`: system level. Homebrew casks, Touch ID for sudo, GitHub's ssh
  host keys.
- `home.nix`: git with per-directory identities and commit signing, gpg,
  direnv, the Claude and Codex CLIs, and whatever the plain config files below
  depend on (oh-my-bash, ble.sh, Crafted Emacs, tree-sitter grammars, language
  tooling). `home-darwin.nix` adds the macOS-only parts: Keychain-backed
  Bedrock access for Claude, the passphrase dialog for gpg, and `rebuild`.
- `.bashrc`, `.bashrc.darwin`, `.bash_profile`, `.tmux.conf`, `.emacs.d/`:
  ordinary config files. `.bashrc` sources the file for the current platform. The Emacs config is built on [Crafted Emacs]. All are symlinked into
  place from the checkout, so edits apply without a rebuild.
- `bootstrap/`: scripts for carrying secrets to, and setting up, a new machine.

## Machines

This repo does not name any machine. Hostnames, usernames and addresses live
in a separate private flake, which takes this one as an input:

```nix
{
  inputs.dotfiles.url = "github:ftlio/dotfiles";

  outputs = { dotfiles, ... }: {
    darwinConfigurations = dotfiles.lib.mkHosts {
      my-hostname = {
        user = "me";
        git = { name = "My Name"; email = "me@example.com"; };
      };
    };
  };
}
```

`hosts/example.nix` documents every field.

With this repo at `~/.dotfiles` and the private flake at `~/.dotfiles-private`,
`rebuild` applies changes. It builds against the local checkout rather than
the revision the private flake has pinned.

## New machine

On a machine that is already set up, `bootstrap/export.sh` writes an encrypted
bundle of GPG keys, the GitHub SSH key and the Bedrock API key, next to a copy
of `bootstrap/install.sh`. Copy that folder to the new Mac and run
`./install.sh`: it installs nix and Homebrew, restores the keys, clones both
repos and runs the first switch.

[nix-darwin]: https://github.com/nix-darwin/nix-darwin
[home-manager]: https://github.com/nix-community/home-manager
[Crafted Emacs]: https://github.com/SystemCrafters/crafted-emacs
