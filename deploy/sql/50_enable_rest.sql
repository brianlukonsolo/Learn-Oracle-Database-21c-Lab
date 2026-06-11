-- =====================================================================
-- 50_enable_rest.sql  --  expose the HR schema through ORDS as REST.
-- Must be run AFTER the ords container has installed ORDS in the DB.
-- Re-runnable.
-- =====================================================================
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT >>> Enabling schema-level REST (base path /hr/)...
BEGIN
  ORDS.ENABLE_SCHEMA(
    p_enabled             => TRUE,
    p_schema              => 'HR',
    p_url_mapping_type    => 'BASE_PATH',
    p_url_mapping_pattern => 'hr',
    p_auto_rest_auth      => FALSE);
  COMMIT;
END;
/

PROMPT >>> Auto-REST enabling tables...
BEGIN
  ORDS.ENABLE_OBJECT(p_enabled=>TRUE, p_schema=>'HR',
    p_object=>'EMPLOYEES',   p_object_type=>'TABLE',
    p_object_alias=>'employees',   p_auto_rest_auth=>FALSE);
  ORDS.ENABLE_OBJECT(p_enabled=>TRUE, p_schema=>'HR',
    p_object=>'DEPARTMENTS', p_object_type=>'TABLE',
    p_object_alias=>'departments', p_auto_rest_auth=>FALSE);
  ORDS.ENABLE_OBJECT(p_enabled=>TRUE, p_schema=>'HR',
    p_object=>'JOBS',        p_object_type=>'TABLE',
    p_object_alias=>'jobs',        p_auto_rest_auth=>FALSE);
  COMMIT;
END;
/

PROMPT >>> Defining a custom report module (/hr/reports/headcount)...
BEGIN
  ORDS.DEFINE_MODULE(
    p_module_name => 'hr.reports',
    p_base_path   => '/reports/',
    p_items_per_page => 25);

  ORDS.DEFINE_TEMPLATE(
    p_module_name => 'hr.reports',
    p_pattern     => 'headcount');

  ORDS.DEFINE_HANDLER(
    p_module_name => 'hr.reports',
    p_pattern     => 'headcount',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_collection_feed,
    p_source      =>
      'SELECT d.department_name, COUNT(*) AS headcount, '||
      'ROUND(AVG(e.salary)) AS avg_salary '||
      'FROM hr.employees e JOIN hr.departments d '||
      'ON d.department_id = e.department_id '||
      'GROUP BY d.department_name ORDER BY headcount DESC');
  COMMIT;
END;
/

PROMPT >>> REST enabled. Modules now defined:
COLUMN name FORMAT A20
COLUMN uri_prefix FORMAT A14
SELECT name, uri_prefix FROM user_ords_modules;
