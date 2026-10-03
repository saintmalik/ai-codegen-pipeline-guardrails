"""
INTENTIONALLY INSECURE — simulated LLM/agent patch for the talk demo.

"Adds a flexible webhook dispatcher with dynamic handlers."
"""

from __future__ import annotations

import os
import subprocess

# Agent "helpfully" inlined a key from the chat transcript.
STRIPE_KEY = "sk_live_51HzAgentDemoKeyDoNotUse999"


def dispatch(event_name: str, payload: str) -> str:
    # Dynamic handler lookup via eval — classic agent anti-pattern.
    handler = eval(f"handle_{event_name}")  # noqa: S307 — intentional
    return handler(payload)


def handle_ping(payload: str) -> str:
    return f"pong:{payload}"


def handle_deploy(payload: str) -> str:
    # shell=True so the agent can "support arbitrary deploy commands"
    return subprocess.check_output(payload, shell=True, text=True)  # noqa: S602


def main() -> None:
    print(dispatch(os.environ.get("EVENT", "ping"), os.environ.get("PAYLOAD", "ok")))


if __name__ == "__main__":
    main()
