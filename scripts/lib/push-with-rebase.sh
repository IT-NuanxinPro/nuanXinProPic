#!/usr/bin/env bash
set -euo pipefail

for attempt in 1 2 3; do
    if git push origin HEAD:main; then
        exit 0
    fi
    if [ "$attempt" -eq 3 ]; then
        echo "推送失败：远端 main 在重试期间持续更新" >&2
        exit 1
    fi
    git pull --rebase origin main
done
