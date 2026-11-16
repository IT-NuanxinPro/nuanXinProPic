#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "${1:-.}" && pwd)"
new_tag="${2:-}"
if [ -z "$new_tag" ]; then
    latest_tag=$(git -C "$project_root" tag -l 'v*' --sort=-version:refname | sed -n '1p')
    if [ -z "$latest_tag" ]; then
        new_tag="v1.0.1"
    else
        IFS='.' read -r major minor patch <<< "${latest_tag#v}"
        new_tag="v${major}.${minor}.$((patch + 1))"
    fi
fi
node "$script_dir/lib/timestamps.mjs" update "$project_root" "$new_tag"
printf '%s\n' "$new_tag" > "${NEW_TAG_FILE:-/tmp/new_tag.txt}"
