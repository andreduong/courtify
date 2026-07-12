#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

WRANGLER="npx wrangler"

echo "==> Checking Cloudflare auth..."
if ! $WRANGLER whoami >/dev/null 2>&1; then
  echo "Not logged in. Run: npx wrangler login"
  exit 1
fi

if grep -q "REPLACE_WITH_PRODUCTION_KV_NAMESPACE_ID" wrangler.toml; then
  echo "==> Creating KV namespaces..."
  PROD_ID=$($WRANGLER kv namespace create TENNIS_DATA 2>&1 | awk '/id = / { gsub(/"/, "", $3); print $3; exit }')
  PREVIEW_ID=$($WRANGLER kv namespace create TENNIS_DATA --preview 2>&1 | awk '/id = / { gsub(/"/, "", $3); print $3; exit }')

  if [[ -z "${PROD_ID}" || -z "${PREVIEW_ID}" ]]; then
    echo "Failed to parse KV namespace IDs. Create them manually and update wrangler.toml."
    exit 1
  fi

  sed -i '' "s/REPLACE_WITH_PRODUCTION_KV_NAMESPACE_ID/${PROD_ID}/" wrangler.toml
  sed -i '' "s/REPLACE_WITH_PREVIEW_KV_NAMESPACE_ID/${PREVIEW_ID}/" wrangler.toml
  echo "==> Updated wrangler.toml with KV IDs."
fi

if [[ -z "${RAPID_API_KEY:-}" ]]; then
  echo "Set RAPID_API_KEY in your environment, then re-run this script."
  echo "Example: RAPID_API_KEY='your-key' ./scripts/deploy-worker.sh"
  exit 1
fi

echo "==> Uploading RAPID_API_KEY secret..."
printf '%s' "$RAPID_API_KEY" | $WRANGLER secret put RAPID_API_KEY

echo "==> Deploying worker..."
DEPLOY_OUTPUT=$($WRANGLER deploy 2>&1)
echo "$DEPLOY_OUTPUT"

WORKER_URL=$(echo "$DEPLOY_OUTPUT" | grep -Eo 'https://[a-zA-Z0-9._-]+\.workers\.dev' | head -1)
if [[ -n "${WORKER_URL}" ]]; then
  API_URL="${WORKER_URL}/api/widget-data"
  echo ""
  echo "==> Worker URL: ${WORKER_URL}"
  echo "==> Widget API: ${API_URL}"
  echo ""
  echo "Update Courtify/Shared/WidgetAPIService.swift with:"
  echo "static let widgetDataURL = URL(string: \"${API_URL}\")!"
fi

echo "==> Triggering initial data refresh..."
if [[ -n "${WORKER_URL:-}" ]]; then
  $WRANGLER dev --test-scheduled --local=false &
  DEV_PID=$!
  sleep 3
  curl -sS "http://localhost:8787/cdn-cgi/handler/scheduled?cron=*/15+*+*+*+*" >/dev/null || true
  kill $DEV_PID 2>/dev/null || true
  echo "Waiting for KV write..."
  sleep 2
  curl -sS "${API_URL}" | head -c 300
  echo ""
fi

echo "==> Done."
