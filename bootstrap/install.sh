#!/bin/bash
#
# Run on a new Mac, from the folder bootstrap/export.sh produced.  Takes the
# machine from a stock install to a fully switched nix-darwin system.
#
# Two repos are involved.  This one is public and holds the configuration;
# the machine descriptions (hostnames, usernames, addresses) live in a private
# flake that takes this one as an input.  A stock Mac has neither git nor
# credentials for the private repo, so the order matters: install nix, borrow
# git and gpg from it, restore the SSH key from the bundle, and only then
# clone.
#
# Written for the stock /bin/bash (3.2).  Safe to re-run.
#
# Usage: ./install.sh [hostname]      (default: this machine's hostname)
#
# The hostname selects the entry in the private flake.  Override the private
# repo with DOTFILES_PRIVATE_REPO.

set -euo pipefail

config=${1:-$(scutil --get LocalHostName)}
repo=https://github.com/ftlio/dotfiles.git
private_repo=${DOTFILES_PRIVATE_REPO:-git@github.com:ftlio/.dotfiles-private.git}
dotfiles=$HOME/.dotfiles
private=$HOME/.dotfiles-private
ssh_key=$HOME/.ssh/github_ftlio
here=$(cd "$(dirname "$0")" && pwd)
bundle=$here/secrets.tar.gpg
nix_profile=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

[ -f "$bundle" ] || { echo "install.sh: $bundle not found" >&2; exit 1; }

# Tools from nixpkgs, for use before the first switch has installed anything.
with_tools() {
    nix --extra-experimental-features 'nix-command flakes' \
        shell nixpkgs#git nixpkgs#gnupg --command "$@"
}

# ---------------------------------------------------------------------------
# Nix and Homebrew
# ---------------------------------------------------------------------------

if [ ! -e "$nix_profile" ]; then
    echo "==> Installing nix"
    curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
fi
# The installer only updates PATH for new shells.
# shellcheck disable=SC1090
command -v nix >/dev/null || . "$nix_profile"

if [ ! -x /opt/homebrew/bin/brew ]; then
    echo "==> Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# ---------------------------------------------------------------------------
# Secrets
# ---------------------------------------------------------------------------

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
chmod 700 "$stage"

echo "==> Decrypting the secrets bundle"
# loopback: read the passphrase on this terminal; no pinentry is set up yet.
with_tools gpg --quiet --pinentry-mode loopback --decrypt "$bundle" | tar -C "$stage" -xf -

if [ ! -f "$ssh_key" ]; then
    echo "==> Restoring the GitHub SSH key"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    cp "$stage/ssh/github_ftlio" "$stage/ssh/github_ftlio.pub" "$HOME/.ssh/"
    chmod 600 "$ssh_key"
fi

# ---------------------------------------------------------------------------
# Clone and switch
# ---------------------------------------------------------------------------

if [ ! -d "$dotfiles/.git" ]; then
    echo "==> Cloning $repo"
    with_tools git clone "$repo" "$dotfiles"
fi

if [ ! -d "$private/.git" ]; then
    echo "==> Cloning $private_repo (asks for the SSH key passphrase)"
    GIT_SSH_COMMAND="/usr/bin/ssh -i $ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
        with_tools git clone "$private_repo" "$private"
fi

echo "==> Switching to $config"
# Build against the checkout just cloned rather than the revision the private
# flake has pinned, as the `rebuild' command does from here on.
if command -v darwin-rebuild >/dev/null; then
    sudo darwin-rebuild switch --flake "$private#$config" \
        --override-input dotfiles "$dotfiles"
else
    sudo nix --extra-experimental-features 'nix-command flakes' \
        run nix-darwin -- switch --flake "$private#$config" \
        --override-input dotfiles "$dotfiles"
fi

# ---------------------------------------------------------------------------
# After the switch
# ---------------------------------------------------------------------------

# Homebrew's bash is installed by the switch; make it the login shell.
brew_bash=/opt/homebrew/bin/bash
if [ -x "$brew_bash" ]; then
    grep -qx "$brew_bash" /etc/shells || echo "$brew_bash" | sudo tee -a /etc/shells >/dev/null
    [ "$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')" = "$brew_bash" ] ||
        chsh -s "$brew_bash"
fi

echo "==> Importing GPG keys"
gpg=/etc/profiles/per-user/$USER/bin/gpg
"$gpg" --batch --import "$stage/gpg-secret-keys.asc"
"$gpg" --import-ownertrust "$stage/gpg-ownertrust.txt"

if [ -f "$stage/bedrock-key" ]; then
    echo "==> Storing the Bedrock key in the Keychain"
    /usr/bin/security add-generic-password -U -a "$USER" -s claude-bedrock \
        -w "$(cat "$stage/bedrock-key")"
fi

echo "==> Saving the SSH key passphrase in the Keychain"
/usr/bin/ssh-add --apple-use-keychain "$ssh_key"

cat <<'EOF'

Done.  Open a new terminal (`rebuild' applies later changes), then:
  * gh auth login, and sign in to claude and codex
  * tick "Save in Keychain" the first time gpg asks for each key's passphrase
  * delete this folder, here and on the machine it came from
EOF
