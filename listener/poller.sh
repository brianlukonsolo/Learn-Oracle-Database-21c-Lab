#!/usr/bin/env bash
# =====================================================================
#  poller.sh  -  the dashboard's data source, running INSIDE the
#  listener container (the "Solaris box").
#
#  It must run here because Oracle 21c refuses REMOTE `lsnrctl` admin
#  over TCP (TNS-01189). Run locally, `lsnrctl status LISTENER` is an
#  authenticated IPC call -- exactly how an operator on the Solaris box
#  would check the listener. We also probe the DB THROUGH the listener
#  (HRDB alias) to prove the routing path end-to-end.
#
#  Output: JSON to /status/status.json (a volume the dashboard serves).
# =====================================================================
set -uo pipefail

export ORACLE_HOME="${ORACLE_HOME:?}"
export PATH="${ORACLE_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${ORACLE_HOME}/lib:${LD_LIBRARY_PATH:-}"
export TNS_ADMIN="${TNS_ADMIN:-/opt/oracle/network/admin}"

LISTENER_NAME="${LISTENER_NAME:-LISTENER}"
DISPLAY_HOST="${LISTENER_HOST:-listener}"
DISPLAY_PORT="${LISTENER_PORT:-1521}"
INTERVAL="${MONITOR_INTERVAL:-3}"
OUT=/status/status.json
TMP=/status/.status.json.tmp

echo "[poller] watching local ${LISTENER_NAME} every ${INTERVAL}s -> ${OUT}"

listener_status() {
    # `lsnrctl status` occasionally returns TNS-12536 ("operation would
    # block") -- a transient non-blocking-socket hiccup. Retry a few times;
    # back-to-back calls reliably succeed. Prints output, returns 0 on success.
    local out=""
    for _ in 1 2 3 4 5; do
        out=$(lsnrctl status "$LISTENER_NAME" 2>&1)
        if printf '%s' "$out" | grep -q "completed successfully"; then
            printf '%s' "$out"
            return 0
        fi
        sleep 0.3
    done
    printf '%s' "$out"
    return 1
}

probe_db() {
    # Connect to the DB THROUGH the listener (HRDB alias) and count employees.
    # Echoes:  <reachable:true|false> <headcount> <error>
    local out rc num code
    out=$(printf 'set heading off feedback off pagesize 0 verify off echo off\nSELECT COUNT(*) FROM hr.employees;\nEXIT;\n' \
            | sqlplus -s -L hr/hr@HRDB 2>&1)
    rc=$?
    num=$(printf '%s\n' "$out" | grep -Eo '[0-9]+' | head -n1)
    if [ "$rc" -eq 0 ] && [ -n "$num" ]; then
        printf 'true %s ' "$num"
    else
        code=$(printf '%s\n' "$out" | grep -Eo '(ORA|TNS)-[0-9]+' | head -n1)
        printf 'false 0 %s' "${code:-unreachable}"
    fi
}

while true; do
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    raw=$(listener_status); lrc=$?
    listener_json=$(printf '%s\n' "$raw" | awk -v rc="$lrc" -f /opt/poller/parse_status.awk)

    read -r db_reach db_count db_err <<<"$(probe_db)"
    db_err="${db_err:-}"

    {
        printf '{'
        printf '"ts":"%s",' "$ts"
        printf '"interval":%s,' "$INTERVAL"
        printf '"listener_host":"%s","listener_port":%s,' "$DISPLAY_HOST" "$DISPLAY_PORT"
        printf '"listener":%s,' "$listener_json"
        printf '"db":{"reachable":%s,"headcount":%s,"error":"%s"}' "$db_reach" "$db_count" "$db_err"
        printf '}\n'
    } > "$TMP"

    mv -f "$TMP" "$OUT"
    sleep "$INTERVAL"
done
