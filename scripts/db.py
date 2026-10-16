"""db: the host description's databases, by name.

  db list                          name, env, driver, address, database
  db show NAME                     one database as JSON (no password)
  db run NAME [--write] [ARG...]   the database's client (mysql, psql,
                                   sqlite3), logged in; ARGs go to it
  db exec NAME [--write] -- CMD    CMD with DB_* variables set (below)

Passwords come from the secret store and are handed to the client or to
CMD, never printed. That keeps them out of terminals and transcripts; it
is not a boundary against anything running as this user, which can read
the secret store itself.

A database tagged env = "prod" is read-only through `db run` (a read-only
session) and refused by `db exec` (which can't enforce that), unless
--write is given. Use --write only when a change to production is meant.

A database with a `tunnel` (an ssh Host with a LocalForward to it) has the
tunnel started when its port isn't answering.

`db exec` sets DB_NAME (the description's name), DB_ENV, DB_DRIVER,
DB_HOST, DB_PORT, DB_DATABASE, DB_USER, DB_PASSWORD and DB_URL (a
driver://user:password@host:port/database URL, or the sqlite file's path),
and MYSQL_PWD or PGPASSWORD for the native clients.
"""
import argparse
import json
import os
import socket
import subprocess
import sys
import time
import urllib.parse

DEFAULT_PORTS = {"mysql": 3306, "postgres": 5432}


def die(msg):
    sys.exit(f"db: {msg}")


def load(path):
    with open(path) as f:
        dbs = json.load(f)
    for name, db in dbs.items():
        db.setdefault("driver", "mysql")
        db.setdefault("env", "dev")
        db["database"] = os.path.expanduser(db.get("database", ""))
        if db["driver"] != "sqlite":
            db.setdefault("host", "localhost")
            db.setdefault("port", DEFAULT_PORTS[db["driver"]])
    return dbs


def get(dbs, name):
    if name not in dbs:
        die(f"no database {name!r}; see `db list`")
    return dbs[name]


def password(secret, name):
    r = subprocess.run([secret, name], capture_output=True, text=True)
    if r.returncode != 0:
        die(f"no password for {name} in the secret store; "
            f"run db-password-set {name}")
    return r.stdout.rstrip("\n")


def port_open(host, port):
    try:
        socket.create_connection((host, port), timeout=1).close()
        return True
    except OSError:
        return False


def ensure_tunnel(db):
    tunnel = db.get("tunnel")
    if not tunnel or port_open(db["host"], db["port"]):
        return
    print(f"db: starting ssh tunnel {tunnel}", file=sys.stderr)
    if subprocess.run(["ssh", "-fN", tunnel]).returncode != 0:
        die(f"could not start the ssh tunnel {tunnel} (on the site's VPN?)")
    for _ in range(20):
        if port_open(db["host"], db["port"]):
            return
        time.sleep(0.25)
    die(f"tunnel {tunnel} started but {db['host']}:{db['port']} isn't answering")


def check_prod(name, db, write, what):
    if db["env"] == "prod" and not write:
        die(f"{name} is production; {what}")


def cmd_list(dbs, args):
    for name, db in sorted(dbs.items()):
        where = (db["database"] if db["driver"] == "sqlite"
                 else f"{db['host']}:{db['port']}/{db['database']}")
        print(f"{name:28} {db['env']:6} {db['driver']:9} {where}")


def cmd_show(dbs, args):
    print(json.dumps({"id": args.name, **get(dbs, args.name)}, indent=2))


def cmd_run(dbs, args):
    db = get(dbs, args.name)
    driver = db["driver"]
    readonly = db["env"] == "prod" and not args.write
    if readonly:
        print(f"db: {args.name} is production; read-only session "
              "(--write to allow changes)", file=sys.stderr)
    if driver == "sqlite":
        cmd = [args.sqlite3] + (["-readonly"] if readonly else [])
        os.execv(cmd[0], cmd + [db["database"], *args.args])
    ensure_tunnel(db)
    env = dict(os.environ)
    pw = password(args.secret, args.name)
    if driver == "mysql":
        # The password goes in through an inherited pipe, as an options
        # file, so it is in neither argv nor the environment.
        r, w = os.pipe()
        quoted = pw.replace("\\", "\\\\").replace('"', '\\"')
        os.write(w, f"[client]\npassword=\"{quoted}\"\n".encode())
        os.close(w)
        cmd = [args.mysql, f"--defaults-extra-file=/dev/fd/{r}",
               "-h", db["host"], "-P", str(db["port"]), "-u", db.get("user", ""),
               "--protocol=TCP"]
        if readonly:
            cmd.append("--init-command=SET SESSION TRANSACTION READ ONLY")
        cmd += [db["database"], *args.args]
        os.set_inheritable(r, True)
        os.execve(cmd[0], cmd, env)
    if driver == "postgres":
        env["PGPASSWORD"] = pw
        if readonly:
            env["PGOPTIONS"] = "-c default_transaction_read_only=on"
        cmd = [args.psql, "-h", db["host"], "-p", str(db["port"]),
               "-U", db.get("user", ""), "-d", db["database"], *args.args]
        os.execve(cmd[0], cmd, env)
    die(f"unknown driver {driver!r}")


def cmd_exec(dbs, args):
    db = get(dbs, args.name)
    check_prod(args.name, db, args.write,
               "db exec can't make it read-only, so it needs --write")
    command = args.args[1:] if args.args[:1] == ["--"] else args.args
    if not command:
        die("usage: db exec NAME [--write] -- COMMAND [ARG...]")
    env = dict(os.environ, DB_NAME=args.name, DB_ENV=db["env"],
               DB_DRIVER=db["driver"], DB_DATABASE=db["database"])
    if db["driver"] == "sqlite":
        env["DB_URL"] = db["database"]
    else:
        ensure_tunnel(db)
        pw = password(args.secret, args.name)
        user = db.get("user", "")
        env.update(DB_HOST=db["host"], DB_PORT=str(db["port"]), DB_USER=user,
                   DB_PASSWORD=pw)
        q = urllib.parse.quote
        env["DB_URL"] = (f"{db['driver']}://{q(user, safe='')}:{q(pw, safe='')}"
                         f"@{db['host']}:{db['port']}/{q(db['database'])}")
        env["MYSQL_PWD" if db["driver"] == "mysql" else "PGPASSWORD"] = pw
    os.execvpe(command[0], command, env)


def main():
    p = argparse.ArgumentParser(prog="db", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    for opt in ("--config", "--secret", "--mysql", "--psql", "--sqlite3"):
        p.add_argument(opt, required=True, help=argparse.SUPPRESS)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    sub.add_parser("show").add_argument("name")
    for name in ("run", "exec"):
        s = sub.add_parser(name)
        s.add_argument("name")
        s.add_argument("--write", action="store_true",
                       help="allow changes to a production database")
        s.add_argument("args", nargs=argparse.REMAINDER)
    args = p.parse_args()
    # REMAINDER takes --write too when it comes after NAME.
    if getattr(args, "args", None) and args.args[0] == "--write":
        args.write = True
        args.args = args.args[1:]
    dbs = load(args.config)
    {"list": cmd_list, "show": cmd_show, "run": cmd_run,
     "exec": cmd_exec}[args.cmd](dbs, args)


if __name__ == "__main__":
    main()
