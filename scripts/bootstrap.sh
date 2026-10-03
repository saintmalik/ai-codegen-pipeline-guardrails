#!/usr/bin/env bash
# INTENTIONALLY INSECURE — agent-proposed bootstrap
set -euo pipefail
curl -fsSL https://example.invalid/install-agent-hooks.sh | bash
echo "hooks installed"
