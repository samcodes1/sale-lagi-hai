#!/usr/bin/env bash
# Applies every migration in supabase/migrations to a throwaway Postgres,
# runs the schema lint, then the pgTAP tests in supabase/tests/database.
#
# Usage: tool/db_test.sh [--keep] [test files...]
#   --keep   leave the cluster running and print its connection string
#   PGHOST/PGPORT/PGUSER/PGDATABASE set: use that existing EMPTY database
#
# Needs Postgres 16+ with PostGIS, pgTAP (pg_prove) and pg_cron:
#   apt-get install postgresql-16-postgis-3 postgresql-16-pgtap postgresql-16-cron
# On the full Supabase stack use `supabase db reset && supabase test db`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPPORT="$ROOT/supabase/tests/support"
KEEP=0
TESTS=()
for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    -*) echo "unknown option $arg" >&2; exit 2 ;;
    *) TESTS+=("$arg") ;;
  esac
done
if [[ ${#TESTS[@]} -eq 0 ]]; then
  mapfile -t TESTS < <(ls "$ROOT"/supabase/tests/database/*.test.sql | sort)
fi

PGBIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1 || true)"
TMP=""
RUN=(sh -c)
[[ $(id -u) -eq 0 ]] && RUN=(su postgres -s /bin/sh -c)
cleanup() {
  if [[ -n "$TMP" && $KEEP -eq 0 ]]; then
    "${RUN[@]}" "$PGBIN/pg_ctl -D $TMP/data -m immediate stop" >/dev/null 2>&1 || true
    rm -rf "$TMP"
  fi
}
trap cleanup EXIT

if [[ -z "${PGHOST:-}" ]]; then
  [[ -x "$PGBIN/initdb" ]] || { echo "Postgres not found; set PGHOST etc." >&2; exit 2; }
  TMP="$(mktemp -d)"
  chmod 755 "$TMP"
  [[ $(id -u) -eq 0 ]] && chown postgres "$TMP"
  PORT=$((54000 + RANDOM % 1000))
  "${RUN[@]}" "$PGBIN/initdb -D $TMP/data -U postgres -A trust >/dev/null"
  "${RUN[@]}" "$PGBIN/pg_ctl -D $TMP/data -l $TMP/log -w start -o \"-p $PORT -k $TMP -c listen_addresses= -c shared_preload_libraries=pg_cron -c cron.database_name=postgres -c timezone=UTC\" >/dev/null"
  export PGHOST="$TMP" PGPORT="$PORT" PGUSER=postgres PGDATABASE=postgres
fi

PSQL=(psql -X -q -v ON_ERROR_STOP=1)
"${PSQL[@]}" -f "$SUPPORT/supabase_stub.sql" >/dev/null

for f in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  echo "# migrate $(basename "$f")"
  "${PSQL[@]}" -f "$f" >/dev/null
done

echo "# schema lint"
"${PSQL[@]}" -f "$SUPPORT/schema_lint.sql" 2>&1 >/dev/null | sed 's/^psql:[^ ]* NOTICE:  //'

echo "# pgTAP"
pg_prove --ext .sql "${TESTS[@]}"

if [[ $KEEP -eq 1 ]]; then echo "# kept: PGHOST=$PGHOST PGPORT=$PGPORT"; fi
