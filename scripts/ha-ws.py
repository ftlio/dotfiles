"""Send one command to Home Assistant's WebSocket API and print the result.

Usage: ha-ws [--write] JSON|@FILE
  ha-ws '{"type": "supervisor/api", "endpoint": "/addons", "method": "get"}'
  ha-ws --write '{"type": "supervisor/api", "endpoint": "/addons/core_letsencrypt/start", "method": "post"}'

The base URL comes from HA_URL and the token from stdin; the ha-ws wrapper
fills both from the Keychain. The REST API can't reach the
Supervisor (add-ons, host); the frontend uses these WebSocket commands, which
take the same admin token. Only plain reads (supervisor/api GETs, and
commands named get_*, */list, */get, */info) run without --write.
"""

import asyncio
import json
import os
import sys

import websockets


def usage():
    sys.exit("usage: ha-ws [--write] JSON|@FILE")


async def main(args):
    write = bool(args) and args[0] == "--write"
    if write:
        args = args[1:]
    if len(args) != 1:
        usage()
    # @FILE reads the command from a file, for commands that carry a secret
    # (argv is visible to ps).
    if args[0].startswith("@"):
        with open(args[0][1:]) as f:
            command = json.load(f)
    else:
        command = json.loads(args[0])
    kind = command["type"]
    if kind == "supervisor/api":
        reads = command.get("method", "get").lower() == "get"
    else:
        reads = kind.startswith("get_") or kind.endswith(("/list", "/get", "/info"))
    if not reads and not write:
        sys.exit("ha-ws: this command may change Home Assistant; pass --write if that is intended")

    token = sys.stdin.read().strip()
    url = os.environ["HA_URL"].rstrip("/")
    ws_url = url.replace("https://", "wss://").replace("http://", "ws://") + "/api/websocket"
    async with websockets.connect(ws_url, max_size=None) as ws:
        json.loads(await ws.recv())  # auth_required
        await ws.send(json.dumps({"type": "auth", "access_token": token}))
        auth = json.loads(await ws.recv())
        if auth.get("type") != "auth_ok":
            sys.exit(f"ha-ws: authentication failed: {auth.get('message', auth)}")
        await ws.send(json.dumps({"id": 1, **command}))
        while True:
            reply = json.loads(await ws.recv())
            if reply.get("id") == 1 and reply.get("type") == "result":
                break
    if not reply.get("success"):
        print(json.dumps(reply.get("error"), indent=2), file=sys.stderr)
        sys.exit(1)
    print(json.dumps(reply.get("result"), indent=2))


asyncio.run(main(sys.argv[1:]))
