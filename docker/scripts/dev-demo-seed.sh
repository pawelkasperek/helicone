#!/usr/bin/env bash
#
# Seeds a local `tier = 'demo'` organization with synthetic request data, so the
# dashboard renders something without integrating a real LLM app.
#
# Usage:
#   ./dev-demo-seed.sh                  # owner = oldest account in the database
#   ./dev-demo-seed.sh me@example.com   # owner = that account
#
# The stack from ../helicone-compose.sh must be running. Re-running replaces the
# demo organization's requests instead of duplicating them.
#
# Why not the built-in seeder? POST /v1/organization/setup-demo spends real
# OpenAI credits and needs the proxy worker on :8787, so it is useless offline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PG_CONTAINER="${PG_CONTAINER:-helicone-postgres-flyway-test}"
PG_DB="${PG_DB:-helicone_test}"
CLICKHOUSE_URL="${CLICKHOUSE_URL:-http://localhost:18123}"
DEMO_ORG_ID="dddddddd-1111-4111-8111-111111111111"

OWNER_EMAIL="${1:-}"

if [ -z "$OWNER_EMAIL" ]; then
  OWNER_EMAIL="$(docker exec "$PG_CONTAINER" psql -U postgres -d "$PG_DB" -tAc \
    'select email from "user" order by "createdAt" limit 1')"
  if [ -z "$OWNER_EMAIL" ]; then
    echo "ERROR: no accounts yet. Create one, then re-run." >&2
    exit 1
  fi
  echo "No owner given, using the oldest account: $OWNER_EMAIL"
fi

echo "== 1/3 demo organization (PostgreSQL) =="
docker exec -i "$PG_CONTAINER" psql -U postgres -d "$PG_DB" \
  -v owner_email="$OWNER_EMAIL" < "$SCRIPT_DIR/dev-demo-seed.sql"

echo "== 2/3 clearing previous demo requests (ClickHouse) =="
curl -sS --fail "$CLICKHOUSE_URL/" \
  --data-binary "DELETE FROM request_response_rmt WHERE organization_id = toUUID('$DEMO_ORG_ID')"

echo "== 3/3 inserting demo requests (ClickHouse) =="
curl -sS --fail "$CLICKHOUSE_URL/" --data-binary "@$SCRIPT_DIR/dev-demo-requests.sql"

echo
echo "Seeded $(curl -sS "$CLICKHOUSE_URL/?query=SELECT%20count()%20FROM%20request_response_rmt%20WHERE%20organization_id%20=%20toUUID('$DEMO_ORG_ID')") demo requests."
echo "Switch to 'Demo Org' in the dashboard organization picker to see them."
