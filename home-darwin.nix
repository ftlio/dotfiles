{ config, pkgs, host, ... }:
let
  # The Bedrock API key lives in the login Keychain, never in this repo or
  # the nix store. Store it with `claude-bedrock-set-key`.
  keychainService = "claude-bedrock";
  bedrockRegion = "us-east-1";

  # Same `claude`, pointed at Bedrock instead of a claude.ai subscription.
  # It shares the default profile's ~/.claude (settings, history, MCP
  # servers) with the work account; see the profiles in home.nix.
  claude-bedrock = pkgs.writeShellScriptBin "claude-bedrock" ''
    if ! token=$(/usr/bin/security find-generic-password -a "$USER" -s ${keychainService} -w 2>/dev/null); then
      echo "claude-bedrock: no key in Keychain; run claude-bedrock-set-key first" >&2
      exit 1
    fi
    unset CLAUDE_CONFIG_DIR
    export CLAUDE_CODE_USE_BEDROCK=1
    export AWS_REGION="''${AWS_REGION:-${bedrockRegion}}"
    export AWS_BEARER_TOKEN_BEDROCK="$token"
    exec ${pkgs.claude-code}/bin/claude "$@"
  '';

  claude-bedrock-set-key = pkgs.writeShellScriptBin "claude-bedrock-set-key" ''
    # Prompts for the key (no echo) and creates or updates the Keychain item.
    # Read here rather than by `security -w`, whose own prompt silently cuts
    # input off at 128 characters -- shorter than a Bedrock API key.
    read -rs -p "Bedrock API key: " key
    echo
    key=''${key//[[:space:]]/}
    [ -n "$key" ] || { echo "claude-bedrock-set-key: no key given" >&2; exit 1; }
    /usr/bin/security add-generic-password -U -a "$USER" -s ${keychainService} -w "$key"
    echo "Stored (''${#key} characters)."
  '';

  # Stores the Jira API token where jira-cli looks for it: a Keychain item
  # with service "jira-cli" and the Jira login as the account.
  jira-set-token = pkgs.writeShellScriptBin "jira-set-token" ''
    config=''${JIRA_CONFIG_FILE:-$HOME/.config/.jira/.config.yml}
    login=$(sed -n 's/^login: *//p' "$config" 2>/dev/null)
    [ -n "$login" ] || read -r -p "Jira login email: " login
    read -rs -p "Jira API token for $login: " token
    echo
    token=''${token//[[:space:]]/}
    [ -n "$token" ] || { echo "jira-set-token: no token given" >&2; exit 1; }
    /usr/bin/security add-generic-password -U -s jira-cli -a "$login" -w "$token"
    echo "Stored (''${#token} characters) for $login."
  '';

  # PagerDuty REST API token, in the Keychain under the service "pagerduty".
  # `pd-api` makes calls with it, so neither scripts nor agents see it.
  pagerdutyService = "pagerduty";

  pagerduty-set-token = pkgs.writeShellScriptBin "pagerduty-set-token" ''
    read -rs -p "PagerDuty API token: " token
    echo
    token=''${token//[[:space:]]/}
    [ -n "$token" ] || { echo "pagerduty-set-token: no token given" >&2; exit 1; }
    /usr/bin/security add-generic-password -U -a "$USER" -s ${pagerdutyService} -w "$token"
    echo "Stored (''${#token} characters)."
  '';

  # Usage: pd-api [--write] [METHOD] PATH [CURL-ARG...]
  #   pd-api /incidents?statuses[]=triggered
  #   pd-api --write PUT /incidents/ID -d @body.json
  # Anything but GET needs --write. PAGERDUTY_API_HOST overrides the host
  # (api.eu.pagerduty.com for an EU account).
  pd-api = pkgs.writeShellScriptBin "pd-api" ''
    write=
    [ "$1" = --write ] && { write=1; shift; }
    method=GET
    case $1 in GET|POST|PUT|PATCH|DELETE) method=$1; shift ;; esac
    path=''${1:?usage: pd-api [--write] [METHOD] PATH [CURL-ARG...]}
    shift
    if [ "$method" != GET ] && [ -z "$write" ]; then
      echo "pd-api: $method changes PagerDuty; pass --write if that is intended" >&2
      exit 1
    fi
    if ! token=$(/usr/bin/security find-generic-password -a "$USER" -s ${pagerdutyService} -w 2>/dev/null); then
      echo "pd-api: no token in Keychain; run pagerduty-set-token first" >&2
      exit 1
    fi
    exec ${pkgs.curl}/bin/curl -sS --fail-with-body -X "$method" \
      -H "Authorization: Token token=$token" \
      -H "Accept: application/vnd.pagerduty+json;version=2" \
      -H "Content-Type: application/json" \
      "https://''${PAGERDUTY_API_HOST:-api.pagerduty.com}/''${path#/}" "$@"
  '';

  # Foreman (foreman.mn) mining-fleet API. The API key is in the Keychain
  # under the service "foreman"; the (non-secret) Client ID, which most paths
  # need, under "foreman-client-id". `foreman-api` reads both at run time, so
  # neither scripts nor agents see the key.
  foremanService = "foreman";
  foremanClientService = "foreman-client-id";
  foremanSessionService = "foreman-session";

  foreman-set-token = pkgs.writeShellScriptBin "foreman-set-token" ''
    read -rs -p "Foreman API key: " token
    echo
    token=''${token//[[:space:]]/}
    [ -n "$token" ] || { echo "foreman-set-token: no key given" >&2; exit 1; }
    read -r -p "Foreman Client ID: " client
    client=''${client//[[:space:]]/}
    [ -n "$client" ] || { echo "foreman-set-token: no client ID given" >&2; exit 1; }
    /usr/bin/security add-generic-password -U -a "$USER" -s ${foremanService} -w "$token"
    /usr/bin/security add-generic-password -U -a "$USER" -s ${foremanClientService} -w "$client"
    echo "Stored key (''${#token} characters) and Client ID $client."
  '';

  # Foreman logs in through SSO, so its browser session token can't be
  # scripted. `foreman-login` opens a headed Chromium (throwaway profile, with
  # Google background networking disabled), waits for you to complete SSO, and
  # captures the bearer token the dashboard sends to foreman.mn, into the
  # Keychain under "foreman-session". `foreman-api --bearer` then uses it. The
  # profile is ephemeral, so you redo SSO each run. The Playwright browser and
  # module come from nix by store path.
  foreman-login = pkgs.writeShellScriptBin "foreman-login" ''
    export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
    export NODE_PATH=${pkgs.playwright-test}/lib/node_modules
    exec ${pkgs.nodejs_22}/bin/node ${./scripts/foreman-login.cjs} "$@"
  '';

  # Usage: foreman-api [--write] [--bearer] [--debug] [METHOD] PATH [CURL-ARG...]
  #   foreman-api /ping/{client}
  #   foreman-api /clients/{client}/miners/summary
  #   foreman-api /clients/{client}/miners/MINER_ID
  # {client} in PATH is replaced by the stored Client ID. Anything but GET
  # needs --write (this API is used read-only). FOREMAN_API_HOST overrides the
  # host. --bearer uses the SSO session token from `foreman-login` (Keychain
  # "foreman-session") with the Bearer scheme, instead of the provisioning key.
  # --debug (or FOREMAN_DEBUG=1) traces the request with curl -v, with the
  # Authorization header redacted from the trace.
  foreman-api = pkgs.writeShellScriptBin "foreman-api" ''
    write=
    bearer=
    debug=''${FOREMAN_DEBUG:+1}
    while :; do
      case $1 in
        --write) write=1; shift ;;
        --bearer) bearer=1; shift ;;
        --debug) debug=1; shift ;;
        *) break ;;
      esac
    done
    method=GET
    case $1 in GET|POST|PUT|PATCH|DELETE) method=$1; shift ;; esac
    path=''${1:?usage: foreman-api [--write] [--bearer] [--debug] [METHOD] PATH [CURL-ARG...]}
    shift
    if [ "$method" != GET ] && [ -z "$write" ]; then
      echo "foreman-api: $method changes Foreman; pass --write if that is intended" >&2
      exit 1
    fi
    if [ -n "$bearer" ]; then
      scheme=Bearer; keyService=${foremanSessionService}; setup="foreman-login"
    else
      scheme=Token; keyService=${foremanService}; setup="foreman-set-token"
    fi
    if ! token=$(/usr/bin/security find-generic-password -a "$USER" -s "$keyService" -w 2>/dev/null); then
      echo "foreman-api: no token in Keychain ($keyService); run $setup first" >&2
      exit 1
    fi
    # Substitute {client} in the path with the stored Client ID.
    case $path in
      *'{client}'*)
        if ! client=$(/usr/bin/security find-generic-password -a "$USER" -s ${foremanClientService} -w 2>/dev/null); then
          echo "foreman-api: no Client ID in Keychain; run foreman-set-token first" >&2
          exit 1
        fi
        path=''${path//'{client}'/$client} ;;
    esac
    set -- -sS --fail-with-body -X "$method" \
      -H "Content-Type: application/json" \
      "https://''${FOREMAN_API_HOST:-api.foreman.mn}/api/v2/''${path#/}" "$@"
    # Keep the key out of argv (process substitution shows as /dev/fd/N in ps)
    # and, in debug mode, out of the trace (sed redacts the header). The <(...)
    # must be on the curl line itself: bash closes it when its command ends, so
    # one made in `set --` is gone by the time curl opens it.
    auth() { printf 'Authorization: %s %s' "$scheme" "$token"; }
    if [ -n "$debug" ]; then
      ${pkgs.curl}/bin/curl -v -H @<(auth) "$@" 2> >(${pkgs.gnused}/bin/sed -E 's/(Authorization: (Token|Bearer) )[^ ]+/\1<redacted>/I' >&2)
    else
      exec ${pkgs.curl}/bin/curl -H @<(auth) "$@"
    fi
  '';

  # OPNsense REST API. A key is made in its web UI (System > Access > Users,
  # the user's API keys), which downloads a file with `key=` and `secret=`
  # lines. Both go in the Keychain under "opnsense-key" and "opnsense-secret",
  # with the (non-secret) host name under "opnsense-host"; `opnsense-api`
  # reads them at run time, so neither scripts nor agents see the secret.
  opnsenseHostService = "opnsense-host";
  opnsenseKeyService = "opnsense-key";
  opnsenseSecretService = "opnsense-secret";

  opnsense-set-key = pkgs.writeShellScriptBin "opnsense-set-key" ''
    host=''${1:?usage: opnsense-set-key HOST APIKEY_FILE}
    file=''${2:?usage: opnsense-set-key HOST APIKEY_FILE}
    key=$(${pkgs.gnused}/bin/sed -n 's/^key=//p' "$file")
    secret=$(${pkgs.gnused}/bin/sed -n 's/^secret=//p' "$file")
    [ -n "$key" ] && [ -n "$secret" ] || { echo "opnsense-set-key: no key= and secret= lines in $file" >&2; exit 1; }
    /usr/bin/security add-generic-password -U -a "$USER" -s ${opnsenseHostService} -w "$host"
    /usr/bin/security add-generic-password -U -a "$USER" -s ${opnsenseKeyService} -w "$key"
    /usr/bin/security add-generic-password -U -a "$USER" -s ${opnsenseSecretService} -w "$secret"
    echo "Stored the key for $host. Delete $file now."
  '';

  # Usage: opnsense-api [--write] [METHOD] PATH [CURL-ARG...]
  #   opnsense-api /dnsmasq/leases/search
  #   opnsense-api --write POST /dnsmasq/service/reconfigure -d '{}'
  # PATH is what follows /api/. Anything but GET needs --write, although many
  # of OPNsense's read-only searches also accept GET.
  opnsense-api = pkgs.writeShellScriptBin "opnsense-api" ''
    write=
    [ "$1" = --write ] && { write=1; shift; }
    method=GET
    case $1 in GET|POST|PUT|PATCH|DELETE) method=$1; shift ;; esac
    path=''${1:?usage: opnsense-api [--write] [METHOD] PATH [CURL-ARG...]}
    shift
    if [ "$method" != GET ] && [ -z "$write" ]; then
      echo "opnsense-api: $method may change OPNsense; pass --write if that is intended" >&2
      exit 1
    fi
    if ! host=$(/usr/bin/security find-generic-password -a "$USER" -s ${opnsenseHostService} -w 2>/dev/null) \
      || ! key=$(/usr/bin/security find-generic-password -a "$USER" -s ${opnsenseKeyService} -w 2>/dev/null) \
      || ! secret=$(/usr/bin/security find-generic-password -a "$USER" -s ${opnsenseSecretService} -w 2>/dev/null); then
      echo "opnsense-api: no key in Keychain; run opnsense-set-key first" >&2
      exit 1
    fi
    # Keep the secret out of argv (process substitution shows as /dev/fd/N in ps).
    auth() { printf 'Authorization: Basic %s' "$(printf '%s:%s' "$key" "$secret" | /usr/bin/base64 | tr -d '\n')"; }
    # OPNsense answers 400 to a JSON content type with no body, as on a GET.
    [ "$method" = GET ] || set -- -H "Content-Type: application/json" "$@"
    exec ${pkgs.curl}/bin/curl -sS --fail-with-body -X "$method" -H @<(auth) \
      "https://$host/api/''${path#/}" "$@"
  '';

  # Home Assistant's REST API. A long-lived access token (Profile → Security →
  # Long-lived access tokens, as an admin) goes in the Keychain under
  # "homeassistant-token", with the (non-secret) base URL under
  # "homeassistant-url"; `ha-api` reads them at run time, so neither scripts
  # nor agents see the token. With an admin's token, /api/hassio/... reaches
  # the Supervisor (add-ons, backups, host).
  haUrlService = "homeassistant-url";
  haTokenService = "homeassistant-token";

  ha-set-token = pkgs.writeShellScriptBin "ha-set-token" ''
    url=''${1:?usage: ha-set-token BASE_URL   (e.g. https://homeassistant.example)}
    read -rs -p "Home Assistant long-lived access token: " token
    echo
    token=''${token//[[:space:]]/}
    [ -n "$token" ] || { echo "ha-set-token: no token given" >&2; exit 1; }
    /usr/bin/security add-generic-password -U -a "$USER" -s ${haUrlService} -w "''${url%/}"
    /usr/bin/security add-generic-password -U -a "$USER" -s ${haTokenService} -w "$token"
    echo "Stored the token (''${#token} characters) for ''${url%/}."
  '';

  # Usage: ha-api [--write] [METHOD] PATH [CURL-ARG...]
  #   ha-api /config
  #   ha-api /hassio/addons
  #   ha-api --write POST /services/light/turn_on -d '{"entity_id":"light.x"}'
  # PATH is what follows /api/. Anything but GET needs --write.
  ha-api = pkgs.writeShellScriptBin "ha-api" ''
    write=
    [ "$1" = --write ] && { write=1; shift; }
    method=GET
    case $1 in GET|POST|PUT|PATCH|DELETE) method=$1; shift ;; esac
    path=''${1:?usage: ha-api [--write] [METHOD] PATH [CURL-ARG...]}
    shift
    if [ "$method" != GET ] && [ -z "$write" ]; then
      echo "ha-api: $method may change Home Assistant; pass --write if that is intended" >&2
      exit 1
    fi
    if ! url=$(/usr/bin/security find-generic-password -a "$USER" -s ${haUrlService} -w 2>/dev/null) \
      || ! token=$(/usr/bin/security find-generic-password -a "$USER" -s ${haTokenService} -w 2>/dev/null); then
      echo "ha-api: no token in Keychain; run ha-set-token first" >&2
      exit 1
    fi
    # Keep the token out of argv (process substitution shows as /dev/fd/N in ps).
    auth() { printf 'Authorization: Bearer %s' "$token"; }
    [ "$method" = GET ] || set -- -H "Content-Type: application/json" "$@"
    exec ${pkgs.curl}/bin/curl -sS --fail-with-body -X "$method" -H @<(auth) \
      "$url/api/''${path#/}" "$@"
  '';

  # `aws sso login` opening its sign-in page in a chosen app, so one SSO
  # session can live in a different browser from the default. The app is
  # AWS_LOGIN_BROWSER if set, else the `login_browser` key of the session's
  # [sso-session NAME] section in ~/.aws/config (the CLI ignores the key). The
  # session is --sso-session's, or that of --profile / AWS_PROFILE. The CLI
  # ignores BROWSER, so this asks it for the URL (--no-browser) and opens
  # that. With no app found it is plain `aws sso login`.
  aws-sso-login = pkgs.writeShellScriptBin "aws-sso-login" ''
    set -o pipefail
    config=''${AWS_CONFIG_FILE:-$HOME/.aws/config}
    ini() { # SECTION KEY: a value from the config file, or nothing
      ${pkgs.gawk}/bin/awk -v s="[$1]" -v k="$2" '
        /^[[:space:]]*\[/ { in_s = ($0 == s) ; next }
        in_s { split($0, kv, "="); key = kv[1]; gsub(/[[:space:]]/, "", key)
               if (key == k) { v = substr($0, index($0, "=") + 1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); print v; exit } }
      ' "$config" 2>/dev/null
    }
    session= profile=''${AWS_PROFILE:-}
    args=("$@")
    for ((i = 0; i < ''${#args[@]}; i++)); do
      case ''${args[i]} in
        --sso-session) session=''${args[i+1]:-} ;;
        --sso-session=*) session=''${args[i]#*=} ;;
        --profile) profile=''${args[i+1]:-} ;;
        --profile=*) profile=''${args[i]#*=} ;;
      esac
    done
    if [ -z "$session" ] && [ -n "$profile" ]; then
      section="profile $profile"
      [ "$profile" = default ] && section=default
      session=$(ini "$section" sso_session)
    fi
    app=''${AWS_LOGIN_BROWSER:-}
    [ -n "$app" ] || [ -z "$session" ] || app=$(ini "sso-session $session" login_browser)
    [ -n "$app" ] || exec ${pkgs.awscli2}/bin/aws sso login "$@"
    opened=
    ${pkgs.awscli2}/bin/aws sso login --no-browser "$@" 2>&1 | while IFS= read -r line; do
      printf '%s\n' "$line"
      case $line in
        https://*)
          if [ -z "$opened" ]; then
            /usr/bin/open -a "$app" "$line"
            opened=1
          fi ;;
      esac
    done
  '';

  # Secrets for the Playwright browser (see playwright-mcp-agent in
  # home.nix), kept in the Keychain under the service "playwright-secret",
  # one item per name (the account field holds the name). Agents refer to
  # them by name; nothing here gives them the values.
  playwrightSecretService = "playwright-secret";

  playwright-secret-set = pkgs.writeShellScriptBin "playwright-secret-set" ''
    # Usage: playwright-secret-set NAME   (prompts for the value, no echo)
    name=''${1:?usage: playwright-secret-set NAME}
    case $name in *[!A-Za-z0-9_]*) echo "playwright-secret-set: use letters, digits and _ only" >&2; exit 1 ;; esac
    read -rs -p "Value for $name: " value
    echo
    [ -n "$value" ] || { echo "playwright-secret-set: no value given" >&2; exit 1; }
    /usr/bin/security add-generic-password -U -s ${playwrightSecretService} -a "$name" -w "$value"
    echo "Stored $name (''${#value} characters)."
  '';

  # Names only; values never printed.
  playwright-secret-list = pkgs.writeShellScriptBin "playwright-secret-list" ''
    /usr/bin/security dump-keychain 2>/dev/null |
      ${pkgs.gawk}/bin/awk '
        /^keychain:/ { acct = ""; svc = "" }
        /"acct"<blob>=/ { sub(/.*"acct"<blob>="/, ""); sub(/"$/, ""); acct = $0 }
        /"svce"<blob>=/ { sub(/.*"svce"<blob>="/, ""); sub(/"$/, ""); svc = $0 }
        /^attributes:/ { acct = ""; svc = "" }
        svc == "${playwrightSecretService}" && acct != "" { print acct; acct = ""; svc = "" }
      ' | sort -u
  '';

  playwright-secrets-dotenv = pkgs.writeShellScriptBin "playwright-secrets-dotenv"
    (builtins.readFile ./scripts/playwright-secrets-dotenv.sh);

  # Rebuilds from the private flake that describes this machine, using the
  # local checkout of this repo instead of the revision pinned there.
  rebuild = pkgs.writeShellScriptBin "rebuild" ''
    # darwin-rebuild runs as root, which has no GitHub key, so private inputs
    # (git+ssh) are fetched first as this user; root then finds them in the
    # store by their locked hash.
    nix flake archive ${host.privateDir} \
      --override-input dotfiles ${host.dotfilesDir} >/dev/null || exit
    exec sudo darwin-rebuild switch --flake ${host.privateDir}#${host.name} \
      --override-input dotfiles ${host.dotfilesDir} "$@"
  '';

  agent-backends-bedrock-el = pkgs.writeText "agent-backends-bedrock.el" ''
    ;;; agent-backends-bedrock.el --- Claude via Bedrock (generated by nix) -*- lexical-binding: t; -*-

    (defun agent-backends--bedrock-token ()
      "Return the Bedrock API key from the login Keychain."
      (with-temp-buffer
        (unless (zerop (call-process "/usr/bin/security" nil t nil
                                     "find-generic-password"
                                     "-a" (user-login-name)
                                     "-s" "${keychainService}" "-w"))
          (user-error "No Bedrock key in Keychain; run claude-bedrock-set-key"))
        (string-trim (buffer-string))))

    ;; Used by `agent-backends--environment' in agent-backends.el, which
    ;; defines the profile commands.
    (defun agent-backends--bedrock-environment ()
      "Return the agent-shell Claude environment for Bedrock."
      (agent-shell-make-environment-variables
       "CLAUDE_CODE_USE_BEDROCK" "1"
       "AWS_REGION" "${bedrockRegion}"
       "AWS_BEARER_TOKEN_BEDROCK" (agent-backends--bedrock-token)
       :inherit-env t))

    (provide 'agent-backends-bedrock)
    ;;; agent-backends-bedrock.el ends here
  '';
in
{
  home.packages = [
    # GNU ls as `gls`, for dired (insert-directory-program in init.el).
    pkgs.coreutils-prefixed
    # Saves a clipboard image to a file; agent-shell uses it to attach
    # screenshots (agent-shell-send-clipboard-image).
    pkgs.pngpaste
    # Containers: colima runs the Linux VM and Docker engine that Docker
    # Desktop would otherwise provide; the rest is the standard client.
    # Start it with `colima start` (see .bashrc.darwin for DOCKER_HOST).
    pkgs.colima
    pkgs.docker-client
    claude-bedrock
    claude-bedrock-set-key
    jira-set-token
    pagerduty-set-token
    pd-api
    foreman-set-token
    foreman-api
    foreman-login
    opnsense-set-key
    opnsense-api
    ha-set-token
    ha-api
    aws-sso-login
    playwright-secret-set
    playwright-secret-list
    playwright-secrets-dotenv
    rebuild
  ];

  # `docker compose` and `docker buildx` are CLI plugins, looked up here.
  # Linked one by one because docker writes its own files (config.json, with
  # registry logins) into ~/.docker.
  home.file.".docker/cli-plugins/docker-compose".source =
    "${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose";
  home.file.".docker/cli-plugins/docker-buildx".source =
    "${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx";

  # Loaded by agent-backends.el.
  home.file.".emacs.d/lisp/agent-backends-bedrock.el".source = agent-backends-bedrock-el;

  home.file.".bashrc.darwin".source =
    config.lib.file.mkOutOfStoreSymlink "${host.dotfilesDir}/.bashrc.darwin";

  # pinentry-mac asks for key passphrases in a dialog (and can save them in
  # the Keychain), so signing works from Emacs, where there is no terminal.
  # The defaults (10 min idle, 2 h max) asked again for nearly every commit.
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry_mac;
    defaultCacheTtl = 28800; # 8 h since the last use
    maxCacheTtl = 86400; # 24 h at most
  };
}
