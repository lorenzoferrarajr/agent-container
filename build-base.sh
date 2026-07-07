#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker build -f Dockerfile.base -t agent-in-container-base:latest .
