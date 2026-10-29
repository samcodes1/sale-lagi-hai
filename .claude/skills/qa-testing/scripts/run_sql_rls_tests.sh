#!/usr/bin/env bash
# Run Supabase migrations + plain-SQL RLS tests against a throwaway local Postgres (no Docker needed).
#
# Usage:
#   run_sql_rls_tests.sh [--self-test] [--migrations DIR] [--tests DIR]
#     --self-test        use the bundled example_migration.sql + example_rls.test.sql
#     --migrations DIR   default: supabase/migrations   (applied in filename order)
#     --tests DIR        default: supabase/tests/sql    (*.test.sql, each wrapped in begin/rollback)
#   DATABASE_URL=postgres://...  use an existing EMPTY database instead of creating a temp cluster.
#
# Exit code is non-zero on the first failing assertion. Output lines are "ok - ..." / "not ok - ...".
# Limitations: this stubs auth.uid()/auth.jwt() and the API roles only. Storage policies, PostGIS,
# pg_cron and Supabase-specific extensions need the real stack (`supabase start` + `supabase test db`).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL="$HERE/sql"
MIGRATIONS="supabase/migrations"
TESTS="supabase/tests/sql"
SELF_TEST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test) SELF_TEST=1; shift ;;
    --migrations) MIGRATIONS="$2"; shift 2 ;;
    --tests) TESTS="$2"; shift 2 ;;
    *) echo "unknown arg $1" >&2; exit 2 ;;
  esac
done

PGBIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1 || true)"
TMP=""
cleanup() {
  if [[ -n "$TMP" ]]; then
    if [[ $(id -u) -eq 0 ]]; then su postgres -s /bin/sh -c "$PGBIN/pg_ctl -D $TMP/data -m immediate stop" >/dev/null 2>&1 || true
    else "$PGBIN/pg_ctl" -D "$TMP/data" -m immediate stop >/dev/null 2>&1 || true; fi
    rm -rf "$TMP"
  fi
}
trap cleanup EXIT

if [[ -z "${DATABASE_URL:-}" ]]; then
  [[ -x "$PGBIN/initdb" ]] || { echo "Postgres binaries not found; set DATABASE_URL" >&2; exit 2; }
  TMP="$(mktemp -d)"; chmod 755 "$TMP"
  PORT=$((54000 + RANDOM % 1000))
  RUN=(sh -c)
  if [[ $(id -u) -eq 0 ]]; then chown postgres "$TMP"; RUN=(su postgres -s /bin/sh -c); fi
  "${RUN[@]}" "$PGBIN/initdb -D $TMP/data -U postgres -A trust >/dev/null"
  "${RUN[@]}" "$PGBIN/pg_ctl -D $TMP/data -o '-p $PORT -k $TMP -c listen_addresses=' -l $TMP/log -w start >/dev/null"
  DATABASE_URL="postgresql://postgres@/postgres?host=$TMP&port=$PORT"
fi

PSQL=(psql "$DATABASE_URL" -X -q -v ON_ERROR_STOP=1 --set=client_min_messages=notice)

"${PSQL[@]}" -c 'create extension if not exists pgcrypto' >/dev/null
"${PSQL[@]}" -f "$SQL/00_supabase_stub.sql" >/dev/null

if [[ $SELF_TEST -eq 1 ]]; then
  MIGRATION_FILES=("$SQL/example_migration.sql"); TEST_FILES=("$SQL/example_rls.test.sql")
else
  mapfile -t MIGRATION_FILES < <(ls "$MIGRATIONS"/*.sql 2>/dev/null | sort)
  mapfile -t TEST_FILES < <(ls "$TESTS"/*.test.sql 2>/dev/null | sort)
fi
[[ ${#MIGRATION_FILES[@]} -gt 0 ]] || { echo "no migrations found in $MIGRATIONS" >&2; exit 2; }

for f in "${MIGRATION_FILES[@]}"; do echo "# migrate $(basename "$f")"; "${PSQL[@]}" -f "$f" >/dev/null; done
echo "# schema lint"; "${PSQL[@]}" -f "$SQL/10_schema_lint.sql" 2>&1 >/dev/null | sed 's/^psql:[^ ]* NOTICE:  //'
for f in "${TEST_FILES[@]}"; do
  echo "# test $(basename "$f")"
  "${PSQL[@]}" -f "$f" 2>&1 >/dev/null | sed 's/^psql:[^ ]* NOTICE:  //; s/^psql:[^ ]* ERROR:  /ERROR: /'
done
echo "# all SQL RLS tests passed"
