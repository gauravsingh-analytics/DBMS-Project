
USE crpsms_db;


-- SECTION 1: MULTI-TABLE JOINS (INNER, OUTER, AND SELF JOINS)


-- 1.1 Complex 5-Table Inner Join: Comprehensive Incident Profile
-- Retrieves incident details along with station name, premises, weapon used, 
-- assigned investigating officer, and current case clearance status.
SELECT 
    f.DR_NO,
    f.Date_Occ,
    f.Time_Occ,
    p.AREA_NAME AS Police_Station,
    pr.Premis_Desc AS Location_Type,
    COALESCE(w.Weapon_Desc, 'No Weapon Reported') AS Weapon_Used,
    o.Name AS Investigating_Officer,
    o.`Rank` AS Officer_Rank,
    cs.Status_Desc AS Case_Status
FROM FIR f
INNER JOIN PoliceStation p ON f.AREA = p.AREA
INNER JOIN Officer o ON f.OfficerID = o.OfficerID
INNER JOIN Premises pr ON f.Premis_Cd = pr.Premis_Cd
LEFT JOIN Weapon w ON f.Weapon_Used_Cd = w.Weapon_Used_Cd
INNER JOIN CaseStatus cs ON f.Status = cs.Status
ORDER BY f.Date_Occ DESC
LIMIT 15;

-- 1.2 Multi-Table Left Outer Join: Officer Workload & Unassigned Analysis
-- Lists all officers along with their active caseload, identifying any officers
-- who have zero assigned cases.
SELECT 
    o.OfficerID,
    o.BadgeNo,
    o.Name AS Officer_Name,
    o.`Rank`,
    p.AREA_NAME AS Station_Assignment,
    COUNT(f.DR_NO) AS Total_Assigned_FIRs,
    SUM(CASE WHEN f.Status = 'AA' THEN 1 ELSE 0 END) AS Arrests_Made,
    SUM(CASE WHEN f.Status = 'IC' THEN 1 ELSE 0 END) AS Pending_Investigations
FROM Officer o
INNER JOIN PoliceStation p ON o.AREA = p.AREA
LEFT JOIN FIR f ON o.OfficerID = f.OfficerID
GROUP BY o.OfficerID, o.BadgeNo, o.Name, o.`Rank`, p.AREA_NAME
ORDER BY Total_Assigned_FIRs DESC, o.OfficerID ASC;

-- 1.3 Self Join: Peer Officer Investigation Pairs
-- Identifies officer pairs who are stationed at the same Police Station and hold
-- the same rank, useful for dispatching 2-officer patrol/detective units.
SELECT 
    p.AREA_NAME AS Police_Station,
    o1.`Rank` AS Shared_Rank,
    o1.Name AS Officer_1,
    o1.BadgeNo AS Badge_1,
    o2.Name AS Officer_2,
    o2.BadgeNo AS Badge_2
FROM Officer o1
INNER JOIN Officer o2 
    ON o1.AREA = o2.AREA 
    AND o1.`Rank` = o2.`Rank` 
    AND o1.OfficerID < o2.OfficerID  -- Avoids self-pairing and duplicate reverse pairs
INNER JOIN PoliceStation p ON o1.AREA = p.AREA
ORDER BY p.AREA_NAME, o1.`Rank`;



-- SECTION 2: CORRELATED SUBQUERIES & AGGREGATIONS (GROUP BY / HAVING)


-- 2.1 Correlated Subquery: Victims Older Than Station Average
-- Finds incident records where the victim's age is strictly higher than the 
-- average victim age for that specific police station division.
-- The inner subquery correlates with the outer query via `f_inner.AREA = f.AREA`.
SELECT 
    f.DR_NO,
    f.Date_Occ,
    ps.AREA_NAME,
    v.VictimID,
    v.Vict_Age,
    v.Vict_Sex,
    (
        SELECT ROUND(AVG(v_sub.Vict_Age), 1)
        FROM FIR f_sub
        INNER JOIN Victim v_sub ON f_sub.DR_NO = v_sub.DR_NO
        WHERE f_sub.AREA = f.AREA
    ) AS Station_Avg_Victim_Age
FROM FIR f
INNER JOIN PoliceStation ps ON f.AREA = ps.AREA
INNER JOIN Victim v ON f.DR_NO = v.DR_NO
WHERE v.Vict_Age > (
    SELECT AVG(v_inner.Vict_Age)
    FROM FIR f_inner
    INNER JOIN Victim v_inner ON f_inner.DR_NO = v_inner.DR_NO
    WHERE f_inner.AREA = f.AREA
)
ORDER BY ps.AREA_NAME, v.Vict_Age DESC
LIMIT 20;

-- 2.2 Aggregation with GROUP BY and HAVING: High-Volume Stations with Part 1 Felonies
-- Calculates station-level clearance rates and filters for stations handling
-- at least 5 incidents with high felony concentrations.
SELECT 
    p.AREA_NAME AS Police_Station,
    COUNT(DISTINCT f.DR_NO) AS Total_Incidents,
    SUM(CASE WHEN ct.Part_1_2 = 1 THEN 1 ELSE 0 END) AS Part_1_Serious_Felonies,
    SUM(CASE WHEN f.Status = 'AA' THEN 1 ELSE 0 END) AS Adult_Arrests,
    ROUND(
        (SUM(CASE WHEN f.Status = 'AA' THEN 1 ELSE 0 END) * 100.0) / COUNT(DISTINCT f.DR_NO), 
        2
    ) AS Clearance_Rate_Pct
FROM PoliceStation p
INNER JOIN FIR f ON p.AREA = f.AREA
INNER JOIN FIR_CrimeType fc ON f.DR_NO = fc.DR_NO
INNER JOIN CrimeType ct ON fc.Crm_Cd = ct.Crm_Cd
GROUP BY p.AREA, p.AREA_NAME
HAVING Total_Incidents >= 5 AND Part_1_Serious_Felonies >= 3
ORDER BY Clearance_Rate_Pct DESC, Total_Incidents DESC;



-- SECTION 3: DATABASE VIEWS FOR BUSINESS METRICS & REPORTING


-- 3.1 View 1: vw_StationCrimePerformance
-- Provides command-level executive metrics for each LAPD station.
DROP VIEW IF EXISTS vw_StationCrimePerformance;
CREATE VIEW vw_StationCrimePerformance AS
SELECT 
    p.AREA AS Station_Code,
    p.AREA_NAME AS Station_Name,
    COUNT(DISTINCT f.DR_NO) AS Total_Crimes_Reported,
    COUNT(DISTINCT o.OfficerID) AS Assigned_Officers,
    SUM(CASE WHEN f.Status = 'AA' THEN 1 ELSE 0 END) AS Solved_Adult_Arrests,
    SUM(CASE WHEN f.Status = 'IC' THEN 1 ELSE 0 END) AS Active_Investigations,
    SUM(CASE WHEN f.Weapon_Used_Cd IS NOT NULL THEN 1 ELSE 0 END) AS Armed_Incidents,
    ROUND(
        (SUM(CASE WHEN f.Status = 'AA' THEN 1 ELSE 0 END) * 100.0) / NULLIF(COUNT(DISTINCT f.DR_NO), 0),
        2
    ) AS Solved_Percentage
FROM PoliceStation p
LEFT JOIN FIR f ON p.AREA = f.AREA
LEFT JOIN Officer o ON p.AREA = o.AREA
GROUP BY p.AREA, p.AREA_NAME;

-- Test View 1
SELECT * FROM vw_StationCrimePerformance ORDER BY Total_Crimes_Reported DESC LIMIT 10;

-- 3.2 View 2: vw_CourtCaseBacklogSummary
-- Tracks judicial backlog of criminal court cases, duration pending, and legal status.
DROP VIEW IF EXISTS vw_CourtCaseBacklogSummary;
CREATE VIEW vw_CourtCaseBacklogSummary AS
SELECT 
    cc.CaseID,
    cc.CaseNo,
    cc.FilingDate,
    c.CourtName,
    c.Jurisdiction,
    f.DR_NO,
    f.Date_Occ,
    ps.AREA_NAME AS Originating_Station,
    a.Name AS Accused_Name,
    a.ArrestDate,
    o.Name AS Arresting_Officer,
    COALESCE(cc.Verdict, 'Pending Trial') AS Current_Verdict_Status,
    CASE 
        WHEN cc.Verdict IS NULL THEN DATEDIFF(CURRENT_DATE(), cc.FilingDate)
        ELSE DATEDIFF(cc.VerdictDate, cc.FilingDate)
    END AS Days_In_Litigation
FROM CourtCase cc
INNER JOIN Court c ON cc.CourtID = c.CourtID
INNER JOIN FIR f ON cc.DR_NO = f.DR_NO
INNER JOIN PoliceStation ps ON f.AREA = ps.AREA
INNER JOIN Officer o ON f.OfficerID = o.OfficerID
LEFT JOIN Accused a ON cc.AccusedID = a.AccusedID;

-- Test View 2
SELECT * FROM vw_CourtCaseBacklogSummary WHERE Current_Verdict_Status = 'Pending Trial' LIMIT 10;



-- SECTION 4: FUNCTIONAL TRIGGERS


-- 4.1 Trigger 1: trg_FIR_Status_Audit
-- Dynamically audits every status modification in the FIR table into CrimeAuditLog.
DROP TRIGGER IF EXISTS trg_FIR_Status_Audit;
DELIMITER $$
CREATE TRIGGER trg_FIR_Status_Audit
AFTER UPDATE ON FIR
FOR EACH ROW
BEGIN
    IF OLD.Status <> NEW.Status THEN
        INSERT INTO CrimeAuditLog (
            DR_NO,
            OldStatus,
            NewStatus,
            ChangedBy,
            ChangedAt,
            ActionDesc
        ) VALUES (
            NEW.DR_NO,
            OLD.Status,
            NEW.Status,
            CURRENT_USER(),
            NOW(),
            CONCAT('Status transition from ', OLD.Status, ' to ', NEW.Status)
        );
    END IF;
END$$
DELIMITER ;

-- 4.2 Trigger 2: trg_Accused_AutoUpdate_FIRStatus
-- Automatically transitions an FIR's status to 'AA' (Adult Arrest) whenever an
-- Accused suspect with an ArrestDate is registered against that FIR.
DROP TRIGGER IF EXISTS trg_Accused_AutoUpdate_FIRStatus;
DELIMITER $$
CREATE TRIGGER trg_Accused_AutoUpdate_FIRStatus
AFTER INSERT ON Accused
FOR EACH ROW
BEGIN
    IF NEW.ArrestDate IS NOT NULL THEN
        UPDATE FIR
        SET Status = 'AA'
        WHERE DR_NO = NEW.DR_NO AND Status = 'IC';
    END IF;
END$$
DELIMITER ;



-- SECTION 5: STORED PROCEDURES (OPERATIONAL TRANSACTIONS WITH ACID CONTROL)


-- 5.1 Stored Procedure 1: sp_RegisterNewFIR
-- Atomic transaction that registers a new incident, attaches its primary crime classification,
-- and records victim details within a single ACID unit of work.
DROP PROCEDURE IF EXISTS sp_RegisterNewFIR;
DELIMITER $$
CREATE PROCEDURE sp_RegisterNewFIR (
    IN p_DR_NO VARCHAR(20),
    IN p_Date_Rptd DATE,
    IN p_Date_Occ DATE,
    IN p_Time_Occ TIME,
    IN p_LOCATION VARCHAR(200),
    IN p_Cross_Street VARCHAR(100),
    IN p_LAT DECIMAL(10, 7),
    IN p_LON DECIMAL(10, 7),
    IN p_AREA INT,
    IN p_Premis_Cd INT,
    IN p_Weapon_Used_Cd INT,
    IN p_OfficerID INT,
    IN p_Crm_Cd INT,
    IN p_Vict_Age INT,
    IN p_Vict_Sex CHAR(1),
    IN p_Vict_Descent CHAR(1)
)
proc_label: BEGIN
    -- Declare SQL exception handler to ensure atomicity
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'TRANSACTION FAILED: Error occurred during FIR registration. All changes rolled back.' AS Result_Status;
    END;

    -- Validate dates
    IF p_Date_Rptd < p_Date_Occ THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Validation Error: Reporting date cannot be prior to incident occurrence date.';
    END IF;

    -- Begin atomic transaction
    START TRANSACTION;

    -- 1. Insert core FIR record
    INSERT INTO FIR (
        DR_NO, Date_Rptd, Date_Occ, Time_Occ, LOCATION, Cross_Street,
        LAT, LON, AREA, Premis_Cd, Weapon_Used_Cd, Status, OfficerID
    ) VALUES (
        p_DR_NO, p_Date_Rptd, p_Date_Occ, p_Time_Occ, p_LOCATION, p_Cross_Street,
        p_LAT, p_LON, p_AREA, p_Premis_Cd, p_Weapon_Used_Cd, 'IC', p_OfficerID
    );

    -- 2. Insert primary crime code into junction table
    INSERT INTO FIR_CrimeType (DR_NO, Crm_Cd)
    VALUES (p_DR_NO, p_Crm_Cd);

    -- 3. Insert victim demographics
    INSERT INTO Victim (Vict_Age, Vict_Sex, Vict_Descent, DR_NO)
    VALUES (p_Vict_Age, p_Vict_Sex, p_Vict_Descent, p_DR_NO);

    -- Commit atomic transaction
    COMMIT;

    SELECT CONCAT('SUCCESS: FIR ', p_DR_NO, ' successfully registered with linked crime code and victim profile.') AS Result_Status;
END$$
DELIMITER ;

-- 5.2 Stored Procedure 2: sp_ProcessArrestAndCourtFiling
-- Transactional procedure: registers an accused suspect, automatically triggers status update,
-- and creates an official judicial court case record.
DROP PROCEDURE IF EXISTS sp_ProcessArrestAndCourtFiling;
DELIMITER $$
CREATE PROCEDURE sp_ProcessArrestAndCourtFiling (
    IN p_DR_NO VARCHAR(20),
    IN p_Accused_Name VARCHAR(100),
    IN p_Accused_Age INT,
    IN p_Accused_Gender CHAR(1),
    IN p_Accused_Address VARCHAR(200),
    IN p_ArrestDate DATE,
    IN p_CaseNo VARCHAR(30),
    IN p_CourtID INT
)
BEGIN
    DECLARE v_AccusedID INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'TRANSACTION FAILED: Court case filing failed. Rolled back.' AS Result_Status;
    END;

    START TRANSACTION;

    -- 1. Insert Accused Record (This triggers trg_Accused_AutoUpdate_FIRStatus)
    INSERT INTO Accused (Name, Age, Gender, Address, ArrestDate, DR_NO)
    VALUES (p_Accused_Name, p_Accused_Age, p_Accused_Gender, p_Accused_Address, p_ArrestDate, p_DR_NO);

    SET v_AccusedID = LAST_INSERT_ID();

    -- 2. Update FIR status if not already updated
    UPDATE FIR SET Status = 'AA' WHERE DR_NO = p_DR_NO;

    -- 3. File Judicial Court Case
    INSERT INTO CourtCase (CaseNo, FilingDate, Verdict, VerdictDate, DR_NO, CourtID, AccusedID)
    VALUES (p_CaseNo, p_ArrestDate, NULL, NULL, p_DR_NO, p_CourtID, v_AccusedID);

    COMMIT;

    SELECT CONCAT('SUCCESS: Accused registered (ID: ', v_AccusedID, ') and Court Case ', p_CaseNo, ' filed.') AS Result_Status;
END$$
DELIMITER ;

-- Demonstration Execution of Stored Procedures & Triggers:
-- Test sp_RegisterNewFIR
CALL sp_RegisterNewFIR(
    '200199999',
    '2024-03-15',
    '2024-03-14',
    '21:30:00',
    '700 S BROADWAY',
    '7TH ST',
    34.0435000,
    -118.2520000,
    1,       -- Central Division
    101,     -- Street
    102,     -- Handgun
    1,       -- Officer ID 1
    210,     -- Robbery
    32,
    'M',
    'H'
);

-- Verify FIR registration
SELECT * FROM FIR WHERE DR_NO = '200199999';

-- Test sp_ProcessArrestAndCourtFiling (which tests Trigger 1 & 2 as well!)
CALL sp_ProcessArrestAndCourtFiling(
    '200199999',
    'Carlos Santana',
    29,
    'M',
    '450 E 5th St, Los Angeles, CA',
    '2024-03-18',
    'BA2024-9999',
    1
);

-- Verify Audit Trigger logged the status change
SELECT * FROM CrimeAuditLog WHERE DR_NO = '200199999';



-- SECTION 6: QUERY OPTIMIZATION & INDEX BENCHMARKING (EXPLAIN)



-- BENCHMARK 1: Multi-Attribute Incident Range Filtering & Classification
-- Query: Filters crimes occurring between dates for specific police divisions
--        and joins with crime classification to filter serious felonies.


-- Step 1.1: Explain Benchmark 1 BEFORE Non-Primary Index
EXPLAIN 
SELECT 
    f.DR_NO,
    f.Date_Occ,
    p.AREA_NAME,
    ct.Crm_Cd_Desc,
    f.LOCATION
FROM FIR f
INNER JOIN PoliceStation p ON f.AREA = p.AREA
INNER JOIN FIR_CrimeType fc ON f.DR_NO = fc.DR_NO
INNER JOIN CrimeType ct ON fc.Crm_Cd = ct.Crm_Cd
WHERE f.Date_Occ BETWEEN '2022-01-01' AND '2023-06-30'
  AND f.AREA IN (1, 2, 3, 6)
  AND ct.Part_1_2 = 1;

-- Step 1.2: Add Composite Index on FIR (Date_Occ, AREA)
-- (Run this statement to create the index for Benchmark 1)
CREATE INDEX idx_fir_date_area ON FIR(Date_Occ, AREA);
-- Note: If you ever need to remove it to re-test: DROP INDEX idx_fir_date_area ON FIR;

-- Step 1.3: Explain Benchmark 1 AFTER Composite Index
EXPLAIN 
SELECT 
    f.DR_NO,
    f.Date_Occ,
    p.AREA_NAME,
    ct.Crm_Cd_Desc,
    f.LOCATION
FROM FIR f
INNER JOIN PoliceStation p ON f.AREA = p.AREA
INNER JOIN FIR_CrimeType fc ON f.DR_NO = fc.DR_NO
INNER JOIN CrimeType ct ON fc.Crm_Cd = ct.Crm_Cd
WHERE f.Date_Occ BETWEEN '2022-01-01' AND '2023-06-30'
  AND f.AREA IN (1, 2, 3, 6)
  AND ct.Part_1_2 = 1;


-- ------------------------------------------------------------------------------
-- BENCHMARK 2: Accused Apprehension & Pending Court Adjudication
-- Query: Identifies pending court cases for suspects arrested within a given
--        timeframe, joining Accused, CourtCase, and Court.
-- ------------------------------------------------------------------------------

-- Step 2.1: Explain Benchmark 2 BEFORE Non-Primary Index
EXPLAIN 
SELECT 
    a.AccusedID,
    a.Name AS Suspect_Name,
    a.ArrestDate,
    cc.CaseNo,
    c.CourtName,
    cc.FilingDate
FROM Accused a
INNER JOIN CourtCase cc ON a.AccusedID = cc.AccusedID
INNER JOIN Court c ON cc.CourtID = c.CourtID
WHERE a.ArrestDate >= '2022-06-01'
  AND cc.Verdict IS NULL;

-- Step 2.2: Add Indexes on Accused (ArrestDate) and CourtCase (Verdict)
-- (Run these statements to create the indexes for Benchmark 2)
CREATE INDEX idx_accused_arrestdate ON Accused(ArrestDate);
CREATE INDEX idx_courtcase_verdict ON CourtCase(Verdict);
-- Note: If you ever need to remove them to re-test:
-- DROP INDEX idx_accused_arrestdate ON Accused;
-- DROP INDEX idx_courtcase_verdict ON CourtCase;

-- Step 2.3: Explain Benchmark 2 AFTER Non-Primary Indexes
EXPLAIN 
SELECT 
    a.AccusedID,
    a.Name AS Suspect_Name,
    a.ArrestDate,
    cc.CaseNo,
    c.CourtName,
    cc.FilingDate
FROM Accused a
INNER JOIN CourtCase cc ON a.AccusedID = cc.AccusedID
INNER JOIN Court c ON cc.CourtID = c.CourtID
WHERE a.ArrestDate >= '2022-06-01'
  AND cc.Verdict IS NULL;

-- Done!
SELECT 'All advanced queries, views, stored procedures, triggers, and benchmarks executed successfully.' AS Final_Status;
