#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin_dir="$repo_root/bin"

mkdir -p "$bin_dir/Contents/Resources"

if [[ ! -x "$bin_dir/drl" ]]; then
  echo "Missing executable: $bin_dir/drl" >&2
  exit 1
fi

if [[ ! -f "$bin_dir/core.wad" || ! -f "$bin_dir/drl.wad" ]]; then
  if [[ ! -x "$bin_dir/makewad" ]]; then
    echo "Missing WAD files and makewad executable in $bin_dir" >&2
    exit 1
  fi
  (cd "$bin_dir" && ./makewad)
fi

export DYLD_LIBRARY_PATH="/opt/homebrew/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

exec "$bin_dir/drl" -graphics -nosound \
  -config "$bin_dir/config.lua" \
  -datapath "$bin_dir/" \
  -writepath "$bin_dir/" \
  -scorepath "$bin_dir/"
