-- =====================================================================
-- 02_hr_seed.sql
-- Baseline reference + employee data for the HR schema.
-- Auto-run ONCE after 01_hr_schema.sql by the gvenzl/oracle-xe image.
-- Extra "realism" rows are loaded later by the in-container deploy
-- script (deploy/sql/40_deploy_payload.sql) to mimic a real rollout.
-- =====================================================================
SET ECHO ON
SET FEEDBACK ON

-- Each init script is a fresh SQL*Plus session in the CDB root; step into
-- the pluggable database again before touching the HR tables.
ALTER SESSION SET CONTAINER = XEPDB1;

PROMPT >>> Seeding regions / countries / locations...
INSERT INTO hr.regions VALUES (1, 'Europe');
INSERT INTO hr.regions VALUES (2, 'Americas');
INSERT INTO hr.regions VALUES (3, 'Asia');

INSERT INTO hr.countries VALUES ('UK', 'United Kingdom', 1);
INSERT INTO hr.countries VALUES ('DE', 'Germany', 1);
INSERT INTO hr.countries VALUES ('US', 'United States', 2);
INSERT INTO hr.countries VALUES ('IN', 'India', 3);

INSERT INTO hr.locations VALUES (100, 'London',    'UK');
INSERT INTO hr.locations VALUES (200, 'Munich',    'DE');
INSERT INTO hr.locations VALUES (300, 'Seattle',   'US');
INSERT INTO hr.locations VALUES (400, 'Bengaluru', 'IN');

PROMPT >>> Seeding jobs...
INSERT INTO hr.jobs VALUES ('AD_PRES',  'President',            20000, 40000);
INSERT INTO hr.jobs VALUES ('IT_MGR',   'IT Manager',          10000, 20000);
INSERT INTO hr.jobs VALUES ('IT_PROG',  'Programmer',           4000, 10000);
INSERT INTO hr.jobs VALUES ('SA_MAN',   'Sales Manager',       10000, 20000);
INSERT INTO hr.jobs VALUES ('SA_REP',   'Sales Representative',  6000, 12000);
INSERT INTO hr.jobs VALUES ('FI_ACC',   'Accountant',           4200,  9000);

PROMPT >>> Seeding departments...
INSERT INTO hr.departments VALUES (10, 'Executive',  100);
INSERT INTO hr.departments VALUES (20, 'IT',         300);
INSERT INTO hr.departments VALUES (30, 'Sales',      100);
INSERT INTO hr.departments VALUES (40, 'Finance',    200);

PROMPT >>> Seeding employees...
INSERT INTO hr.employees VALUES (100,'Steven','King','SKING','+44.20.1234',TO_DATE('2003-06-17','YYYY-MM-DD'),'AD_PRES',38000,NULL,10);
INSERT INTO hr.employees VALUES (101,'Nina','Patel','NPATEL','+1.206.555.01',TO_DATE('2005-01-13','YYYY-MM-DD'),'IT_MGR',18000,100,20);
INSERT INTO hr.employees VALUES (102,'Bruce','Ernst','BERNST','+1.206.555.02',TO_DATE('2007-05-21','YYYY-MM-DD'),'IT_PROG',9000,101,20);
INSERT INTO hr.employees VALUES (103,'David','Austin','DAUSTIN','+1.206.555.03',TO_DATE('2009-06-25','YYYY-MM-DD'),'IT_PROG',7800,101,20);
INSERT INTO hr.employees VALUES (104,'Ellen','Abel','EABEL','+44.20.5678',TO_DATE('2004-05-11','YYYY-MM-DD'),'SA_MAN',17000,100,30);
INSERT INTO hr.employees VALUES (105,'Peter','Tucker','PTUCKER','+44.20.9012',TO_DATE('2005-01-30','YYYY-MM-DD'),'SA_REP',10000,104,30);
INSERT INTO hr.employees VALUES (106,'Anita','Sharma','ASHARMA','+49.89.4321',TO_DATE('2008-03-24','YYYY-MM-DD'),'FI_ACC',8200,100,40);

COMMIT;

PROMPT >>> Baseline HR data committed.
SELECT 'employees seeded: ' || COUNT(*) AS summary FROM hr.employees;
