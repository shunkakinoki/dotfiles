#!/usr/bin/env bash
set -euo pipefail

BASE_URL="http://127.0.0.1:@coordinatorPort@"

for _ in $("@coreutils@/bin/seq" 1 90); do
  if "@curl@/bin/curl" --fail --silent --show-error "$BASE_URL/v1/health" >/dev/null &&
    "@curl@/bin/curl" --fail --silent --show-error "$BASE_URL/v1/ready" >/dev/null; then
    exit 0
  fi
  "@coreutils@/bin/sleep" 1
done

echo "Crabbox coordinator did not become healthy and ready" >&2
exit 1
