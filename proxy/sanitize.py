#!/usr/bin/env python3
"""Strips tools/tool_choice out of chat requests before they reach vllm.

open-webui sends tool defs on every request. vllm 400s without a tool parser,
and with one the model calls tools that don't exist instead of answering.
Everything else passes through, streaming included.
"""
import os, sys, traceback
from aiohttp import web, ClientSession, ClientTimeout, TCPConnector

UPSTREAM = os.environ.get("UPSTREAM", "http://vllm:8000").rstrip("/")
STRIP = ("tools", "tool_choice", "functions", "function_call", "parallel_tool_calls")

HOP_BY_HOP = {"host", "content-length", "accept-encoding",
              "transfer-encoding", "connection", "keep-alive"}


async def proxy(request: web.Request) -> web.StreamResponse:
    try:
        raw = await request.read()

        body = None
        if raw:
            try:
                import json
                body = json.loads(raw)
            except Exception:
                body = None

        stripped = []
        if isinstance(body, dict):
            for k in STRIP:
                if body.pop(k, None) is not None:
                    stripped.append(k)

        if request.path.endswith("/chat/completions"):
            print(f"chat: stripped={stripped or 'nothing'}", flush=True)

        headers = {k: v for k, v in request.headers.items()
                   if k.lower() not in HOP_BY_HOP}

        # aiohttp won't take json= and data= together, and neither on a GET
        kwargs = {"headers": headers}
        if isinstance(body, dict):
            kwargs["json"] = body
        elif raw:
            kwargs["data"] = raw

        session = request.app["session"]
        async with session.request(
                request.method, f"{UPSTREAM}{request.path_qs}", **kwargs) as up:
            resp = web.StreamResponse(status=up.status, headers={
                k: v for k, v in up.headers.items()
                if k.lower() not in HOP_BY_HOP | {"content-encoding"}})
            await resp.prepare(request)
            async for chunk in up.content.iter_any():
                await resp.write(chunk)
            await resp.write_eof()
            return resp

    except Exception:
        # json, not a plaintext 500 - openai clients parse the error body
        traceback.print_exc(file=sys.stderr)
        return web.json_response(
            {"error": {"message": "proxy failure", "type": "proxy_error"}},
            status=502)


async def health(_: web.Request) -> web.Response:
    return web.json_response({"status": "ok", "upstream": UPSTREAM})


async def on_start(app):
    # one session for the process, not one per request
    app["session"] = ClientSession(
        timeout=ClientTimeout(total=None, sock_read=None, sock_connect=30),
        connector=TCPConnector(limit=256, keepalive_timeout=60))


async def on_stop(app):
    await app["session"].close()


app = web.Application(client_max_size=64 * 1024 ** 2)
app.on_startup.append(on_start)
app.on_cleanup.append(on_stop)
app.router.add_get("/healthz", health)
app.router.add_route("*", "/{tail:.*}", proxy)

if __name__ == "__main__":
    print(f"sanitising proxy -> {UPSTREAM}", flush=True)
    web.run_app(app, host="0.0.0.0", port=8010, access_log=None)
