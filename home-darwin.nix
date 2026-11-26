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
      -H @<(printf 'Authorization: %s %s' "$scheme" "$token") \
      -H "Content-Type: application/json" \
      "https://''${FOREMAN_API_HOST:-api.foreman.mn}/api/v2/''${path#/}" "$@"
    # Keep the key out of argv (process substitution shows as /dev/fd/N in ps)
    # and, in debug mode, out of the trace (sed redacts the header).
    if [ -n "$debug" ]; then
      ${pkgs.curl}/bin/curl -v "$@" 2> >(${pkgs.gnused}/bin/sed -E 's/(Authorization: (Token|Bearer) )[^ ]+/\1<redacted>/I' >&2)
    else
      exec ${pkgs.curl}/bin/curl "$@"
    fi
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
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry_mac;
  };
}
