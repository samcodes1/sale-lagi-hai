#!/usr/bin/env bash
# Deploys the Edge Functions to the `edge-functions` service on Railway
# (self-hosted Supabase). Uploads only what the image needs: the functions
# and the router in deploy/edge-runtime.
#
# Usage: tool/deploy_functions.sh   (needs `railway login` and `railway link`)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTX="$(mktemp -d)"
trap 'rm -rf "$CTX"' EXIT
mkdir -p "$CTX/supabase" "$CTX/deploy/edge-runtime"
rsync -a --exclude '*.test.ts' --exclude 'fixtures' "$ROOT/supabase/functions" "$CTX/supabase/"
cp -R "$ROOT/deploy/edge-runtime/main" "$CTX/deploy/edge-runtime/"
cp "$ROOT/deploy/edge-runtime/Dockerfile" "$CTX/Dockerfile"
railway up "$CTX" --path-as-root --service edge-functions --ci
