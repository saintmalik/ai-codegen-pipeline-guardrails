"""
Fixed webhook dispatcher — same feature, safe patterns.

Secrets from env; typed handler map; no shell=True.
"""

from __future__ import annotations

import os
from collections.abc import Callable

# Required at runtime; never hardcoded.
STRIPE_KEY = os.environ["STRIPE_API_KEY"]

Handler = Callable[[str], str]
HANDLERS: dict[str, Handler] = {}


def register(name: str):
    def deco(fn: Handler) -> Handler:
        HANDLERS[name] = fn
        return fn

    return deco


@register("ping")
def handle_ping(payload: str) -> str:
    return f"pong:{payload}"


@register("echo")
def handle_echo(payload: str) -> str:
    return payload


def dispatch(event_name: str, payload: str) -> str:
    handler = HANDLERS.get(event_name)
    if handler is None:
        raise KeyError(f"unknown event: {event_name}")
    return handler(payload)


def main() -> None:
    print(dispatch(os.environ.get("EVENT", "ping"), os.environ.get("PAYLOAD", "ok")))


if __name__ == "__main__":
    main()
