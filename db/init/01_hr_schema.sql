-- =====================================================================
-- 01_hr_schema.sql
-- Creates the HR demo schema inside the XEPDB1 pluggable database.
-- This file is auto-run ONCE by the gvenzl/oracle-xe image because it
-- lives in /container-entrypoint-initdb.d (mounted from db/init).
-- It is executed as a privileged user, already inside XEPDB1.
-- =====================================================================
SET ECHO ON
SET FEEDBACK ON

-- gvenzl runs init scripts against the CDB root. Step INTO the pluggable
-- database so HR becomes a normal LOCAL user (with its tables and privileges)
-- inside XEPDB1 -- NOT a common user in CDB$ROOT.
PROMPT >>> Switching into the XEPDB1 pluggable database...
ALTER SESSION SET CONTAINER = XEPDB1;

PROMPT >>> Creating HR application user...
CREATE USER hr IDENTIFIED BY "hr"
  DEFAULT TABLESPACE users
  QUOTA UNLIMITED ON users;

GRANT CONNECT, RESOURCE TO hr;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW,
      CREATE PROCEDURE, CREATE SEQUENCE TO hr;

PROMPT >>> Creating reference tables...
CREATE TABLE hr.regions (
  region_id    NUMBER PRIMARY KEY,
  region_name  VARCHAR2(40)
);

CREATE TABLE hr.countries (
  country_id    CHAR(2) PRIMARY KEY,
  country_name  VARCHAR2(60),
  region_id     NUMBER REFERENCES hr.regions(region_id)
);

CREATE TABLE hr.locations (
  location_id    NUMBER PRIMARY KEY,
  city           VARCHAR2(40),
  country_id     CHAR(2) REFERENCES hr.countries(country_id)
);

CREATE TABLE hr.jobs (
  job_id      VARCHAR2(12) PRIMARY KEY,
  job_title   VARCHAR2(40) NOT NULL,
  min_salary  NUMBER(8),
  max_salary  NUMBER(8)
);

CREATE TABLE hr.departments (
  department_id    NUMBER PRIMARY KEY,
  department_name  VARCHAR2(40) NOT NULL,
  location_id      NUMBER REFERENCES hr.locations(location_id)
);

PROMPT >>> Creating employees table...
CREATE TABLE hr.employees (
  employee_id    NUMBER PRIMARY KEY,
  first_name     VARCHAR2(30),
  last_name      VARCHAR2(30) NOT NULL,
  email          VARCHAR2(40) NOT NULL,
  phone_number   VARCHAR2(25),
  hire_date      DATE NOT NULL,
  job_id         VARCHAR2(12) REFERENCES hr.jobs(job_id),
  salary         NUMBER(8,2),
  manager_id     NUMBER REFERENCES hr.employees(employee_id),
  department_id  NUMBER REFERENCES hr.departments(department_id)
);

CREATE INDEX hr.emp_dept_ix ON hr.employees(department_id);
CREATE INDEX hr.emp_job_ix  ON hr.employees(job_id);

PROMPT >>> HR schema objects created.
