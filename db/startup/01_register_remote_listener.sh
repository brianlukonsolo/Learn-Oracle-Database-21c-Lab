#!/usr/bin/env bash
# =====================================================================
# Runs on EVERY database start (gvenzl /container-entrypoint-startdb.d).
# Tells this database instance to register its services with the
# listener that lives on the SEPARATE 'listener' host container.
#
# This is the line that wires "DB on one box" to "listener on another".
# After this, the listener host's `lsnrctl services` will show XEPDB1.
# =====================================================================
set -e

LISTENER_HOST="${REMOTE_LISTENER_HOST:-listener}"
LISTENER_PORT="${REMOTE_LISTENER_PORT:-1521}"

echo "[startup] Waiting for listener host '${LISTENER_HOST}' to resolve..."
for i in $(seq 1 30); do
  if getent hosts "${LISTENER_HOST}" >/dev/null 2>&1; then
    echo "[startup] '${LISTENER_HOST}' resolved."
    break
  fi
  sleep 2
done

ADDR="(ADDRESS=(PROTOCOL=TCP)(HOST=${LISTENER_HOST})(PORT=${LISTENER_PORT}))"
echo "[startup] Setting remote_listener = ${ADDR}"

sqlplus -s / as sysdba <<SQL || echo "[startup] WARN: remote_listener registration failed (will retry on next start)"
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER SYSTEM SET remote_listener='${ADDR}' SCOPE=BOTH;
ALTER SYSTEM REGISTER;
COLUMN value FORMAT A50
SELECT value FROM v\$parameter WHERE name = 'remote_listener';
EXIT
SQL

echo "[startup] Done. PMON will (re)register XE / XEPDB1 with the listener host."
