#!/usr/bin/env bash
# =====================================================================
# enable-rest.sh  --  turn the HR schema into REST APIs via ORDS.
# Run INSIDE the listener host, AFTER the `ords` container has finished
# installing ORDS into the database (watch: docker compose logs -f ords).
#
#   docker compose exec listener /deploy/enable-rest.sh
#
# Endpoints become available at:
#   http://localhost:8080/ords/hr/employees/
#   http://localhost:8080/ords/hr/departments/
#   http://localhost:8080/ords/hr/jobs/
#   http://localhost:8080/ords/hr/reports/headcount
# =====================================================================
set -euo pipefail
export TNS_ADMIN="${TNS_ADMIN:-/opt/oracle/network/admin}"

DB_USER="${1:-hr}"
DB_PASS="${2:-hr}"
TNS_ALIAS="${3:-HRDB}"

echo ">> Enabling ORDS REST on schema ${DB_USER} via ${TNS_ALIAS} ..."
sqlplus -s "${DB_USER}/${DB_PASS}@${TNS_ALIAS}" @/deploy/sql/50_enable_rest.sql
echo ">> REST enabled. Try: curl http://localhost:8080/ords/hr/employees/"
