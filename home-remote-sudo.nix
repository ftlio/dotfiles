# Running sudo on another machine over ssh without typing its password, so
# agents and scripts can do things like a remote darwin-rebuild. The password
# lives in the login Keychain (service "remote-sudo", account = ssh host) and is
# piped to `sudo -S` on the far side; it is never printed or put in argv.
#
# Each item is created trusting no application (-T ""), so every read raises a
# macOS dialog: approve with the login password and "Allow". Choosing "Always
# Allow" adds /usr/bin/security to the item's access list and silences future
# prompts, so that anything running as this user could then become root there;
# rerun remote-sudo-set to restore the prompt. Remove an entry when it is no
# longer needed:
#   security delete-generic-password -s remote-sudo -a HOST
{ pkgs, ... }:

let
  service = "remote-sudo";

  remote-sudo-set = pkgs.writeShellScriptBin "remote-sudo-set" ''
    # Usage: remote-sudo-set HOST   (prompts for HOST's sudo password, no echo)
    host=''${1:?usage: remote-sudo-set HOST}
    case $host in *[!A-Za-z0-9._-]*) echo "remote-sudo-set: bad host name" >&2; exit 1 ;; esac
    read -rsp "sudo password for $host: " value; echo
    [ -n "$value" ] || { echo "remote-sudo-set: no password given" >&2; exit 1; }
    # Recreate rather than update (-U), so an old access list doesn't carry over.
    /usr/bin/security delete-generic-password -s ${service} -a "$host" >/dev/null 2>&1
    # -T "": trust no application, so every use asks for approval.
    /usr/bin/security add-generic-password -s ${service} -a "$host" -T "" -w "$value"
  '';

  remote-sudo = pkgs.writeShellScriptBin "remote-sudo" ''
    # Usage: remote-sudo HOST COMMAND [ARG...]   (runs COMMAND as root on HOST)
    host=''${1:?usage: remote-sudo HOST COMMAND [ARG...]}; shift
    [ $# -gt 0 ] || { echo "usage: remote-sudo HOST COMMAND [ARG...]" >&2; exit 1; }
    # Raises the Keychain approval dialog (see the top of this file).
    if ! pw=$(/usr/bin/security find-generic-password -s ${service} -a "$host" -w 2>/dev/null); then
      echo "remote-sudo: no access to $host's password (denied, or not stored: remote-sudo-set $host)" >&2
      exit 1
    fi
    # -k: always consume the password line, even if sudo has a cached ticket,
    # so it can't leak into COMMAND's stdin. printf is a builtin: not in ps.
    printf '%s\n' "$pw" | /usr/bin/ssh "$host" "sudo -S -k -p ''' -- $(printf '%q ' "$@")"
  '';
in
{
  home.packages = [ remote-sudo-set remote-sudo ];
}
