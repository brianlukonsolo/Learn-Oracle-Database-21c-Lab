#!/usr/bin/env bash
# =====================================================================
# Entry point for the listener host container.
# Runs ONLY an Oracle Net listener (no database) in the foreground so
# the container stays alive and streams listener output to `docker logs`.
# =====================================================================
set -euo pipefail

export TNS_ADMIN="${TNS_ADMIN:-/opt/oracle/network/admin}"
export ORACLE_HOME="${ORACLE_HOME:?ORACLE_HOME not set}"
export LD_LIBRARY_PATH="${ORACLE_HOME}/lib:${LD_LIBRARY_PATH:-}"
export PATH="${ORACLE_HOME}/bin:${PATH}"

echo "============================================================"
echo " ORACLE NET LISTENER HOST  (the 'Solaris box' of this lab)"
echo " ORACLE_HOME = ${ORACLE_HOME}"
echo " TNS_ADMIN   = ${TNS_ADMIN}"
echo " Listening   = TCP 0.0.0.0:1521"
echo " Database    = registers remotely from container 'oracle-db'"
echo "============================================================"

# tnslsnr run directly (not via lsnrctl) stays in the FOREGROUND, which
# is exactly what we want for a container's main process.
exec tnslsnr LISTENER
