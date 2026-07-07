#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker build --no-cache -f Dockerfile -t agent-in-container:latest .
