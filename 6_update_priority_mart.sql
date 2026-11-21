
SELECT '=== Updating Priority Mart ===' AS Info;

-- Updating Data Engineer role priority level to 1
UPDATE priority_mart.priority_roles
SET priority_level = 1
WHERE role_name = 'Data Engineer';

-- Inserting a new role Data Analyst with priority level as 3

INSERT INTO priority_mart.priority_roles
(role_id,
role_name,
priority_level)
VALUES
(4, 'Data Analyst', 3);

SELECT * from priority_mart.priority_roles;

CREATE OR REPLACE TEMP TABLE src_priority_jobs AS 
SELECT 
  jpf.job_id,
  jpf.job_title_short,
  cd.name AS company_name,
  jpf.job_posted_date,
  jpf.salary_year_avg,
  r.priority_level,
  CURRENT_TIMESTAMP AS updated_at
FROM
    job_postings_fact AS jpf                          
LEFT JOIN company_dim AS cd                           
    ON jpf.company_id = cd.company_id
INNER JOIN priority_mart.priority_roles AS r               
    ON jpf.job_title_short = r.role_name;

-- Step 4: MERGE operation to update snapshot
-- This MERGE statement handles:
-- - Updates when priority_level changes (WHEN MATCHED)
-- - Inserts for new jobs (WHEN NOT MATCHED)
-- - Deletes for jobs no longer in source (WHEN NOT MATCHED BY SOURCE)
MERGE INTO priority_mart.priority_jobs_snapshot AS tgt     
USING src_priority_jobs AS src
ON tgt.job_id = src.job_id

WHEN MATCHED AND tgt.priority_level IS DISTINCT FROM src.priority_level THEN
    UPDATE SET
        priority_level = src.priority_level,
        updated_at = src.updated_at

WHEN NOT MATCHED THEN
    INSERT (
        job_id,
        job_title_short,
        company_name,
        job_posted_date,
        salary_year_avg,
        priority_level,
        updated_at
    )
    VALUES (
        src.job_id,
        src.job_title_short,
        src.company_name,
        src.job_posted_date,
        src.salary_year_avg,
        src.priority_level,
        src.updated_at
    )

WHEN NOT MATCHED BY SOURCE THEN DELETE;

SELECT 'Priority Roles Dimension' AS table_name, COUNT(*) as record_count FROM priority_mart.priority_roles
UNION ALL
SELECT 'Priority Jobs Snapshot', COUNT(*) FROM priority_mart.priority_jobs_snapshot;

SELECT '=== Priority Roles Dimension Sample ===' AS info;
SELECT * FROM priority_mart.priority_roles;

SELECT '=== Priority Jobs Snapshot Sample ===' AS info;
SELECT 
    job_title_short,
    COUNT(*) AS job_count,
    MIN(priority_level) AS priority_level,
    MIN(updated_at) AS updated_at
FROM priority_mart.priority_jobs_snapshot          
GROUP BY job_title_short
ORDER BY job_count DESC;