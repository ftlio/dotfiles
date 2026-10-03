#!/usr/bin/env bash
#
# Run on a machine that is already set up.  Writes a folder holding everything
# a new machine needs before it can clone the private repo that describes it:
#
#   install.sh        run this on the new machine
#   secrets.tar.gpg   GPG keys, the SSH keys and the Bedrock key,
#                     encrypted with a passphrase chosen here
#
# Usage: bootstrap/export.sh [output-dir]      (default: ~/dotfiles-bootstrap)

set -euo pipefail

out=${1:-$HOME/dotfiles-bootstrap}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ssh_keys="github_ftlio id_ed25519 vbkey"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
chmod 700 "$stage"

echo "gpg: exporting secret keys and trust"
gpg --export-secret-keys --armor > "$stage/gpg-secret-keys.asc"
gpg --export-ownertrust > "$stage/gpg-ownertrust.txt"

mkdir "$stage/ssh"
for key in $ssh_keys; do
    if [[ -f $HOME/.ssh/$key ]]; then
        echo "ssh: copying $key"
        cp "$HOME/.ssh/$key" "$HOME/.ssh/$key.pub" "$stage/ssh/"
    else
        echo "ssh: no $key, skipping"
    fi
done

# Optional: only present once claude-bedrock-set-key has been run.
if /usr/bin/security find-generic-password -a "$USER" -s claude-bedrock -w \
     > "$stage/bedrock-key" 2>/dev/null; then
    echo "bedrock: copying key from Keychain"
else
    rm -f "$stage/bedrock-key"
    echo "bedrock: no key in Keychain, skipping"
fi

mkdir -p "$out"
rm -f "$out/secrets.tar.gpg"
echo "Choose a passphrase for the bundle; install.sh asks for it."
tar -C "$stage" -cf - . |
    gpg --symmetric --cipher-algo AES256 --no-symkey-cache -o "$out/secrets.tar.gpg"
cp "$here/install.sh" "$out/install.sh"
chmod +x "$out/install.sh"

cat <<EOF

Wrote $out
Copy that folder to the new machine (AirDrop or a USB stick, not cloud
storage), run ./install.sh there, then delete the folder on both machines.
EOF
