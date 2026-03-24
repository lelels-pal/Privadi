#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export HOME="$ROOT/.home"
export TMPDIR="$ROOT/.tmp"
export CLANG_MODULE_CACHE_PATH="$ROOT/.cache/clang"
export SWIFTPM_TESTS_MODULECACHE="$ROOT/.cache/swiftpm-tests"

mkdir -p "$ROOT/.home" "$ROOT/.build" "$ROOT/.tmp" "$ROOT/.cache/clang" "$ROOT/.cache/swiftpm-tests"
cd "$ROOT"

swift test --disable-sandbox --scratch-path "$ROOT/.build"
