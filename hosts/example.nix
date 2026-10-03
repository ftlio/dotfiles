# A host description. Real ones live in a private flake that passes an
# attribute set of them, keyed by hostname, to this flake's lib.mkHosts.
{
  # macOS account that owns the home-manager configuration.
  user = "me";

  git = {
    name = "My Name";
    email = "me@example.com";
    # GPG key (ID or user ID) for signing commits and tags. Optional; omit to
    # leave signing off.
    signingKey = "me@example.com";
    # Optional. Identities that replace the default for repos under a directory.
    identities = [
      {
        gitdir = "~/personal/";
        email = "me@personal.example";
        signingKey = "me@personal.example";
      }
    ];
  };

  # Optional, with their defaults:
  # system = "aarch64-darwin";
  # dotfilesDir = "/Users/me/.dotfiles";          # checkout of this repo
  # privateDir = "/Users/me/.dotfiles-private";   # checkout of the private flake
  # emacsExtra = "";                              # elisp for lisp/host-local.el
  # sshConfig = "";                               # ssh_config Host blocks, placed
  #                                               # before the generic ones
}
