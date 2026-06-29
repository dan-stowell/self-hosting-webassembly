#!/usr/bin/env bash
# Download wasi-sdk (clang + wasm-ld + wasi-libc) into tools/wasi-sdk. This is
# the C/C++ -> wasm bridge for the "compile the wasm world into wasm" roadmap
# (see runtimes/ROADMAP.md). Self-contained; produces wasi_snapshot_preview1
# wasm that runs under our tcc-built toywasm. ~185 MB, gitignored.
set -euo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
dest="$repo/tools/wasi-sdk"
[ -x "$dest/bin/clang" ] && { echo "[wasi-sdk] already present: $("$dest/bin/clang" --version | head -1)"; exit 0; }

mkdir -p "$repo/tools"
url=$(gh api repos/WebAssembly/wasi-sdk/releases/latest --jq '.assets[].browser_download_url' 2>/dev/null \
        | grep -E 'x86_64-linux\.tar\.gz$' | head -1)
[ -n "$url" ] || { echo "[wasi-sdk] could not resolve latest release URL (need gh/network)"; exit 1; }
echo "[wasi-sdk] downloading $url"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
curl -sSL "$url" -o "$tmp/wasi-sdk.tar.gz"
tar xzf "$tmp/wasi-sdk.tar.gz" -C "$tmp"
mv "$tmp"/wasi-sdk-*-x86_64-linux "$dest"
echo "[wasi-sdk] ready: $("$dest/bin/clang" --version | head -1)"
