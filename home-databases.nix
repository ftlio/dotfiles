# Database connections from the host description (`databases`), written
# into DBeaver by `dbeaver-sync` and usable by name, from a shell or an
# agent, through `db` (scripts/db.py: `db list`, `db run NAME`, `db exec
# NAME -- CMD`). Each is tagged local, dev or prod; prod is read-only
# through `db` unless --write is given. Hosts, ports and users are in the host
# description; passwords are in the platform's secret store, one per
# database, under the service "db-password" with the database's name as the
# account:
#   macOS  the login Keychain   (security)
#   Linux  the Secret Service   (secret-tool; GNOME Keyring, KWallet,
#                                KeePassXC)
# Store one with `db-password-set NAME`.
{ config, pkgs, lib, host, ... }:

let
  service = "db-password";
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  # Prints NAME's password. Used by db and dbeaver-sync, not put on PATH.
  db-password-get = pkgs.writeShellScript "db-password-get" (
    if isDarwin then ''
      exec /usr/bin/security find-generic-password -s ${service} -a "$1" -w
    '' else ''
      exec ${pkgs.libsecret}/bin/secret-tool lookup service ${service} account "$1"
    '');

  db-password-set = pkgs.writeShellScriptBin "db-password-set" ''
    # Usage: db-password-set NAME   (prompts for the password, no echo)
    name=''${1:?usage: db-password-set NAME}
    case $name in *[!A-Za-z0-9._-]*) echo "db-password-set: bad name" >&2; exit 1 ;; esac
    read -rs -p "Password for $name: " value
    echo
    [ -n "$value" ] || { echo "db-password-set: no password given" >&2; exit 1; }
    ${if isDarwin then ''
      /usr/bin/security add-generic-password -U -s ${service} -a "$name" -w "$value"
    '' else ''
      printf '%s' "$value" |
        ${pkgs.libsecret}/bin/secret-tool store --label="Database $name" service ${service} account "$name"
    ''}
    echo "Stored. Run dbeaver-sync (with DBeaver closed) to use it."
  '';

  # Everything but the passwords, which never come here.
  databasesJson = pkgs.writeText "databases.json" (builtins.toJSON host.databases);

  db = pkgs.writeShellScriptBin "db" ''
    exec ${pkgs.python3}/bin/python3 ${./scripts/db.py} \
      --config ${databasesJson} \
      --secret ${db-password-get} \
      --mysql ${pkgs.mysql84}/bin/mysql \
      --psql ${pkgs.postgresql}/bin/psql \
      --sqlite3 ${pkgs.sqlite}/bin/sqlite3 "$@"
  '';

  dbeaverWorkspace =
    if isDarwin
    then "$HOME/Library/DBeaverData/workspace6/General/.dbeaver"
    else "$HOME/.local/share/DBeaverData/workspace6/General/.dbeaver";

  dbeaver-sync = pkgs.writeShellScriptBin "dbeaver-sync" ''
    # For pgrep, which activation's PATH may lack.
    export PATH="$PATH:/usr/bin"
    exec ${pkgs.python3}/bin/python3 ${./scripts/dbeaver-sync.py} \
      --config ${databasesJson} \
      --workspace "${dbeaverWorkspace}" \
      --secret ${db-password-get} \
      --openssl ${pkgs.openssl}/bin/openssl "$@"
  '';
in
lib.mkIf (host.databases != { }) {
  home.packages = [ db db-password-set dbeaver-sync ];

  # The same descriptions, for other tools (and agents' skills) to read.
  home.file.".config/databases.json".source = databasesJson;

  # Sync on every switch too. Not fatal: DBeaver may be open, in which case
  # run dbeaver-sync after quitting it.
  home.activation.dbeaverSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${dbeaver-sync}/bin/dbeaver-sync ||
      echo "warning: DBeaver connections not synced; run dbeaver-sync" >&2
  '';
}
