-- =====================================================================
-- 40_deploy_payload.sql  --  the data this lab "deploys".
-- Run by deploy.sh from inside the listener host, through alias HRDB.
-- Idempotent: it clears its own generated range first, so you can run
-- the deploy as many times as you like.
-- =====================================================================
SET SERVEROUTPUT ON
SET FEEDBACK ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT >>> Connected as:
SELECT USER AS connected_as, SYS_CONTEXT('USERENV','CON_NAME') AS pdb,
       SYS_CONTEXT('USERENV','SERVER_HOST') AS db_host FROM dual;

PROMPT >>> Clearing previously deployed rows (employee_id >= 200)...
DELETE FROM hr.employees WHERE employee_id >= 200;

PROMPT >>> Generating 20 employees across IT / Sales / Finance...
BEGIN
  FOR i IN 0 .. 19 LOOP
    INSERT INTO hr.employees
      (employee_id, first_name, last_name, email, hire_date,
       job_id, salary, manager_id, department_id)
    VALUES
      (200 + i,
       'Gen' || i,
       'Worker' || i,
       'GW' || (200 + i),
       SYSDATE - MOD(i * 37, 4000),
       CASE MOD(i, 3) WHEN 0 THEN 'IT_PROG' WHEN 1 THEN 'SA_REP' ELSE 'FI_ACC' END,
       5000 + (i * 125),
       CASE WHEN MOD(i, 3) = 1 THEN 104 ELSE 101 END,
       CASE MOD(i, 3) WHEN 0 THEN 20 WHEN 1 THEN 30 ELSE 40 END);
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Deployed 20 generated employees (ids 200-219).');
END;
/

PROMPT >>> Post-deploy headcount by department:
COLUMN department_name FORMAT A18
SELECT d.department_name,
       COUNT(*)            AS headcount,
       ROUND(AVG(e.salary)) AS avg_salary
FROM   hr.employees e
JOIN   hr.departments d ON d.department_id = e.department_id
GROUP  BY d.department_name
ORDER  BY headcount DESC;
