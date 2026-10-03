# Prints NAME=value lines (dotenv) for every agent secret in the Keychain,
# for Playwright MCP's --secrets.  Dotenv has no escapes inside quotes, so
# each value is wrapped in a quote character it does not contain.
/etc/profiles/per-user/"$USER"/bin/agent-secret-list | while read -r name; do
  value=$(/usr/bin/security find-generic-password -s agent-secret -a "$name" -w 2>/dev/null) || continue
  if [[ $value == *$'\n'* ]]; then
    echo "agent-secrets-dotenv: skipping $name, multi-line values are not supported" >&2
    continue
  fi
  q=
  for c in "'" '`' '"'; do
    if [[ $value != *"$c"* ]]; then q=$c; break; fi
  done
  if [[ -z $q ]]; then
    echo "agent-secrets-dotenv: skipping $name, it contains every quote character" >&2
    continue
  fi
  printf '%s=%s%s%s\n' "$name" "$q" "$value" "$q"
done
