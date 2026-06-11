# =====================================================================
# Listener host image.
# Reuses the Oracle XE binaries (tnslsnr / lsnrctl / sqlplus) but runs
# ONLY a listener -- no database. This models a host that has the Oracle
# Net listener installed, separate from the database instance.
# =====================================================================
FROM gvenzl/oracle-xe:21-slim-faststart

USER root

ENV TNS_ADMIN=/opt/oracle/network/admin

# Net configuration (listener.ora / sqlnet.ora / tnsnames.ora)
COPY network/admin/ /opt/oracle/network/admin/

# Foreground listener entrypoint
COPY entrypoint.sh /opt/oracle/listener-entrypoint.sh
RUN chmod +x /opt/oracle/listener-entrypoint.sh \
 && chmod -R a+r /opt/oracle/network/admin

USER oracle

HEALTHCHECK --interval=15s --timeout=10s --start-period=20s --retries=10 \
  CMD lsnrctl status LISTENER >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/opt/oracle/listener-entrypoint.sh"]
