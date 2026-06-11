#!/usr/bin/env bash
# =====================================================================
# deploy.sh  --  THE DEPLOY SCRIPT.
# Runs INSIDE the listener-host container (never on your laptop).
# It connects to the database *through this listener host* (alias HRDB)
# and loads a batch of "realism" data -- mimicking a production rollout
# performed from the Solaris box at work.
#
# Usage (from your laptop):
#   docker compose exec listener /deploy/deploy.sh
#   docker compose exec listener /deploy/deploy.sh hr hr HRDB_DIRECT
# =====================================================================
set -euo pipefail

export TNS_ADMIN="${TNS_ADMIN:-/opt/oracle/network/admin}"

DB_USER="${1:-hr}"
DB_PASS="${2:-hr}"
TNS_ALIAS="${3:-HRDB}"      # HRDB = via listener host ; HRDB_DIRECT = bypass

echo "============================================================"
echo " DEPLOY  ->  user=${DB_USER}  alias=${TNS_ALIAS}"
echo " (TNS_ALIAS HRDB routes through THIS listener host to the DB)"
echo "============================================================"
echo
echo ">> tnsping ${TNS_ALIAS}"
tnsping "${TNS_ALIAS}" || { echo "tnsping failed"; exit 1; }
echo
sqlplus -s "${DB_USER}/${DB_PASS}@${TNS_ALIAS}" @/deploy/sql/40_deploy_payload.sql

echo
echo "Deploy complete."
