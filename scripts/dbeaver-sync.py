"""Writes the host description's databases into a DBeaver workspace.

Connections go into data-sources.json under ids prefixed "dotfiles-"; any
other connection (made in DBeaver's UI) is left alone. A dotfiles- connection
no longer in the description is removed. Edits made in the UI to a managed
connection are overwritten on the next sync.

Passwords come from the secret backend (the Keychain on macOS) through the
--secret command, and go into credentials-config.json. DBeaver obfuscates
that file with a key built into DBeaver, so it is no safer than plain text
to anything that can read it; it is kept mode 600. A connection with no
password in the backend keeps whatever DBeaver already has for it.

DBeaver keeps both files in memory and writes them back on exit, so this
refuses to run while it is open.
"""
import argparse
import json
import os
import subprocess
import sys

# DBeaver's built-in key for credentials-config.json (AES-128-CBC, with the
# IV as the file's first 16 bytes).
CREDENTIALS_KEY = "babb4a9f774ab853c96c2d653dfe544a"
ID_PREFIX = "dotfiles-"

# A database's env, as one of DBeaver's built-in connection types.
# Production is drawn in red and asks before executing or changing data.
ENV_TYPES = {"local": "dev", "dev": "test", "prod": "prod"}

DRIVERS = {
    "mysql": {
        "provider": "mysql",
        "driver": "mysql8",
        "port": 3306,
        "url": "jdbc:mysql://{host}:{port}/{database}",
        # Needed to log in to MySQL 8 with caching_sha2_password without TLS.
        "properties": {"allowPublicKeyRetrieval": "true"},
        "provider-properties": {"@dbeaver-show-all-dbs@": "true"},
    },
    "postgres": {
        "provider": "postgresql",
        "driver": "postgres-jdbc",
        "port": 5432,
        "url": "jdbc:postgresql://{host}:{port}/{database}",
        "provider-properties": {"@pg-show-all-dbs@": "true"},
    },
    # `database` is the file's path; there is no host, port or login.
    "sqlite": {
        "provider": "sqlite",
        "driver": "sqlite_jdbc",
        "url": "jdbc:sqlite:{database}",
    },
}


def connection(name, db):
    kind = db.get("driver", "mysql")
    if kind not in DRIVERS:
        sys.exit(f"dbeaver-sync: {name}: unknown driver {kind!r} "
                 f"(one of {', '.join(DRIVERS)})")
    d = DRIVERS[kind]
    env = db.get("env", "dev")
    if env not in ENV_TYPES:
        sys.exit(f"dbeaver-sync: {name}: unknown env {env!r} "
                 f"(one of {', '.join(ENV_TYPES)})")
    database = os.path.expanduser(db.get("database", ""))
    config = {"database": database}
    if "port" in d:
        config["host"] = db.get("host", "localhost")
        config["port"] = str(db.get("port", d["port"]))
    config["url"] = d["url"].format(**config)
    config.update({
        "configurationType": "MANUAL",
        "type": ENV_TYPES[env],
        "closeIdleConnection": True,
        "properties": {**d.get("properties", {}), **db.get("properties", {})},
        "provider-properties": d.get("provider-properties", {}),
        "auth-model": "native",
    })
    conn = {
        "provider": d["provider"],
        "driver": d["driver"],
        "name": db.get("name", name),
        "save-password": True,
        "configuration": config,
    }
    for field in ("folder", "description"):
        if db.get(field):
            conn[field] = db[field]
    return conn


def openssl(args, data, binary):
    return subprocess.run([binary, "enc", "-aes-128-cbc", "-K", CREDENTIALS_KEY,
                           *args], input=data, capture_output=True,
                          check=True).stdout


def read_credentials(path, binary):
    if not os.path.exists(path):
        return {}
    with open(path, "rb") as f:
        raw = f.read()
    plain = openssl(["-d", "-iv", raw[:16].hex()], raw[16:], binary)
    return json.loads(plain)


def write_credentials(path, creds, binary):
    iv = os.urandom(16)
    data = iv + openssl(["-iv", iv.hex()],
                        json.dumps(creds).encode(), binary)
    write(path, data, 0o600)


def write(path, data, mode):
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    os.replace(tmp, path)


def password(secret, name):
    r = subprocess.run([secret, name], capture_output=True, text=True)
    return r.stdout.rstrip("\n") if r.returncode == 0 else None


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--config", required=True)
    p.add_argument("--workspace", required=True)
    p.add_argument("--secret", required=True)
    p.add_argument("--openssl", required=True)
    args = p.parse_args()

    if subprocess.run(["pgrep", "-x", "dbeaver"],
                      capture_output=True).returncode == 0:
        sys.exit("dbeaver-sync: DBeaver is running; quit it first "
                 "(it would overwrite the changes on exit)")

    with open(args.config) as f:
        databases = json.load(f)
    os.makedirs(args.workspace, exist_ok=True)
    sources_path = os.path.join(args.workspace, "data-sources.json")
    creds_path = os.path.join(args.workspace, "credentials-config.json")

    sources = {"folders": {}, "connections": {}}
    if os.path.exists(sources_path):
        with open(sources_path) as f:
            sources = json.load(f)
    connections = sources.setdefault("connections", {})
    folders = sources.setdefault("folders", {})
    creds = read_credentials(creds_path, args.openssl)

    for cid in [c for c in connections if c.startswith(ID_PREFIX)]:
        if cid[len(ID_PREFIX):] not in databases:
            del connections[cid]
            creds.pop(cid, None)
            print(f"removed {cid}")

    for name, db in sorted(databases.items()):
        cid = ID_PREFIX + name
        conn = connection(name, db)
        connections[cid] = conn
        if conn.get("folder"):
            folders.setdefault(conn["folder"], {})
        if db.get("driver") == "sqlite":
            print(f"wrote {cid}")
            continue
        login = dict(creds.get(cid, {}).get("#connection", {}))
        if db.get("user"):
            login["user"] = db["user"]
        pw = password(args.secret, name)
        if pw is not None:
            login["password"] = pw
            status = "password from the secret store"
        elif "password" in login:
            status = "no password in the secret store; kept DBeaver's"
        else:
            status = "no password in the secret store"
        creds[cid] = {"#connection": login}
        print(f"wrote {cid} ({status})")

    write(sources_path, (json.dumps(sources, indent="\t") + "\n").encode(),
          0o644)
    write_credentials(creds_path, creds, args.openssl)


if __name__ == "__main__":
    main()
