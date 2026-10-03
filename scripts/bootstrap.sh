#!/usr/bin/env bash
# Safe bootstrap — pinned installer, no pipe-to-shell.
set -euo pipefail
INSTALLER_URL="https://example.invalid/install-agent-hooks.sh"
INSTALLER_SHA256="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
# In a real pipeline: curl -fsSL "$INSTALLER_URL" -o "$tmpdir/install.sh"
# then: echo "${INSTALLER_SHA256}  $tmpdir/install.sh" | sha256sum -c -
# then: bash "$tmpdir/install.sh"
echo "Would fetch $INSTALLER_URL and verify $INSTALLER_SHA256 (demo stub)"
