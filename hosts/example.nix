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

  # Optional. Database connections, written into DBeaver by `dbeaver-sync`
  # (and on every switch) and usable by name with `db` (`db list`). The
  # attribute name is the connection's id and the name its password is
  # stored under: `db-password-set app-dev`. Passwords never go here.
  databases = {
    app-dev = {
      env = "dev";               # local, dev (default) or prod; prod is
                                 # read-only through `db` without --write
      driver = "postgres";       # mysql (default), postgres or sqlite
      name = "app (dev)";        # shown in DBeaver; defaults to the id
      host = "localhost";        # default localhost
      port = 15432;              # default: the driver's usual port
      database = "app";          # for sqlite, the file's path
      user = "app";
      tunnel = "app-db";         # optional ssh Host whose LocalForward
                                 # reaches it; `db` starts it when needed
      folder = "Work";           # optional DBeaver folder
      description = "Through the app-db ssh tunnel";
      properties = { };          # extra JDBC driver properties
    };
  };

  # Optional, with their defaults:
  # system = "aarch64-darwin";
  # dotfilesDir = "/Users/me/.dotfiles";          # checkout of this repo
  # privateDir = "/Users/me/.dotfiles-private";   # checkout of the private flake
  # emacsExtra = "";                              # elisp for lisp/host-local.el
  # sshConfig = "";                               # ssh_config Host blocks, placed
  #                                               # before the generic ones
  # awsConfig = "";                               # ~/.aws/config (profiles, SSO
  #                                               # sessions); unmanaged if empty
  # extraModules = [ ];                           # nix-darwin modules for this
  #                                               # host only, e.g. a service
  #                                               # from another flake's
  #                                               # darwinModules
}
