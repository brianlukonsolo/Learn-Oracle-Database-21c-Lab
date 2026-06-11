SET PAGES 200 LINES 160
COLUMN con FORMAT A12
COLUMN privilege FORMAT A25
PROMPT === CON_NAME this session routed to ===
SELECT SYS_CONTEXT('USERENV','CON_NAME') con FROM dual;
PROMPT === HR exists here? ===
SELECT username, common, account_status FROM dba_users WHERE username = 'HR';
PROMPT === HR system privileges here ===
SELECT privilege FROM dba_sys_privs WHERE grantee = 'HR' ORDER BY 1;
PROMPT === HR roles here ===
SELECT granted_role FROM dba_role_privs WHERE grantee = 'HR';
PROMPT === employee count here ===
SELECT COUNT(*) emp_count FROM hr.employees;
EXIT
