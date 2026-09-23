
-- 1. Database Initialization
DROP DATABASE IF EXISTS crpsms_db;
CREATE DATABASE crpsms_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE crpsms_db;


-- Table 1: PoliceStation (Lookup / Independent Entity)
-- Represents LAPD Divisions / Station Houses

CREATE TABLE PoliceStation (
    AREA INT NOT NULL,
    AREA_NAME VARCHAR(80) NOT NULL,
    CONSTRAINT pk_policestation PRIMARY KEY (AREA),
    CONSTRAINT uq_policestation_name UNIQUE (AREA_NAME)
) ENGINE=InnoDB;

-- ------------------------------------------------------------------------------
-- Table 2: Officer
-- Investigating Officers / Detectives attached to a Police Station
-- ------------------------------------------------------------------------------
CREATE TABLE Officer (
    OfficerID INT NOT NULL AUTO_INCREMENT,
    BadgeNo VARCHAR(20) NOT NULL,
    Name VARCHAR(100) NOT NULL,
    `Rank` VARCHAR(40) NOT NULL,
    AREA INT NOT NULL,
    CONSTRAINT pk_officer PRIMARY KEY (OfficerID),
    CONSTRAINT uq_officer_badgeno UNIQUE (BadgeNo),
    CONSTRAINT fk_officer_station FOREIGN KEY (AREA)
        REFERENCES PoliceStation (AREA)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- Table 3: CrimeType (Lookup)
-- California Penal Code / LAPD Crime classification
-- Part_1_2: 1 = Serious/Felony (Part I), 2 = Misdemeanor/Minor (Part II)

CREATE TABLE CrimeType (
    Crm_Cd INT NOT NULL,
    Crm_Cd_Desc VARCHAR(150) NOT NULL,
    Part_1_2 INT NOT NULL,
    CONSTRAINT pk_crimetype PRIMARY KEY (Crm_Cd),
    CONSTRAINT chk_part_1_2 CHECK (Part_1_2 IN (1, 2))
) ENGINE=InnoDB;

-- ------------------------------------------------------------------------------
-- Table 4: Premises (Lookup)
-- Incident location categorization (e.g., Street, Residence, Commercial Store)
-- ------------------------------------------------------------------------------
CREATE TABLE Premises (
    Premis_Cd INT NOT NULL,
    Premis_Desc VARCHAR(150) NOT NULL,
    CONSTRAINT pk_premises PRIMARY KEY (Premis_Cd)
) ENGINE=InnoDB;


-- Table 5: Weapon (Lookup)
-- Weapon / Force category used in commission of crime

CREATE TABLE Weapon (
    Weapon_Used_Cd INT NOT NULL,
    Weapon_Desc VARCHAR(150) NOT NULL,
    CONSTRAINT pk_weapon PRIMARY KEY (Weapon_Used_Cd)
) ENGINE=InnoDB;


-- Table 6: CaseStatus (Lookup)
-- Current status of investigation:
-- IC: Investigation Continued
-- AA: Adult Arrest
-- AO: Adult Other
-- JA: Juvenile Arrest
-- JO: Juvenile Other

CREATE TABLE CaseStatus (
    Status VARCHAR(10) NOT NULL,
    Status_Desc VARCHAR(80) NOT NULL,
    CONSTRAINT pk_casestatus PRIMARY KEY (Status)
) ENGINE=InnoDB;


-- Table 7: FIR (Central Relation)
-- First Information Report (Incident Register)
-- Links Station, Premises, Weapon, CaseStatus, and Investigating Officer

CREATE TABLE FIR (
    DR_NO VARCHAR(20) NOT NULL,
    Date_Rptd DATE NOT NULL,
    Date_Occ DATE NOT NULL,
    Time_Occ TIME NULL,
    LOCATION VARCHAR(200) NULL,
    Cross_Street VARCHAR(100) NULL,
    LAT DECIMAL(10, 7) NULL,
    LON DECIMAL(10, 7) NULL,
    AREA INT NOT NULL,
    Premis_Cd INT NULL,
    Weapon_Used_Cd INT NULL,
    Status VARCHAR(10) NOT NULL DEFAULT 'IC',
    OfficerID INT NOT NULL,
    CONSTRAINT pk_fir PRIMARY KEY (DR_NO),
    CONSTRAINT fk_fir_station FOREIGN KEY (AREA)
        REFERENCES PoliceStation (AREA)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_fir_premises FOREIGN KEY (Premis_Cd)
        REFERENCES Premises (Premis_Cd)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_fir_weapon FOREIGN KEY (Weapon_Used_Cd)
        REFERENCES Weapon (Weapon_Used_Cd)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_fir_status FOREIGN KEY (Status)
        REFERENCES CaseStatus (Status)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_fir_officer FOREIGN KEY (OfficerID)
        REFERENCES Officer (OfficerID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_fir_dates CHECK (Date_Rptd >= Date_Occ)
) ENGINE=InnoDB;


-- Table 8: FIR_CrimeType (M:N Junction Relation)
-- Maps multiple crime classifications to a single FIR (1NF resolution)

CREATE TABLE FIR_CrimeType (
    DR_NO VARCHAR(20) NOT NULL,
    Crm_Cd INT NOT NULL,
    CONSTRAINT pk_fir_crimetype PRIMARY KEY (DR_NO, Crm_Cd),
    CONSTRAINT fk_fct_fir FOREIGN KEY (DR_NO)
        REFERENCES FIR (DR_NO)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_fct_crime FOREIGN KEY (Crm_Cd)
        REFERENCES CrimeType (Crm_Cd)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- Table 9: Victim
-- Demographic profile of individual victims associated with an FIR

CREATE TABLE Victim (
    VictimID INT NOT NULL AUTO_INCREMENT,
    Vict_Age INT NULL,
    Vict_Sex CHAR(1) NULL,
    Vict_Descent CHAR(1) NULL,
    DR_NO VARCHAR(20) NOT NULL,
    CONSTRAINT pk_victim PRIMARY KEY (VictimID),
    CONSTRAINT fk_victim_fir FOREIGN KEY (DR_NO)
        REFERENCES FIR (DR_NO)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT chk_victim_age CHECK (Vict_Age >= 0 AND Vict_Age <= 125),
    CONSTRAINT chk_victim_sex CHECK (Vict_Sex IN ('M', 'F', 'X'))
) ENGINE=InnoDB;


-- Table 10: Accused
-- Named or apprehended suspect(s) associated with an FIR

CREATE TABLE Accused (
    AccusedID INT NOT NULL AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Age INT NULL,
    Gender CHAR(1) NULL,
    Address VARCHAR(200) NULL,
    ArrestDate DATE NULL,
    DR_NO VARCHAR(20) NOT NULL,
    CONSTRAINT pk_accused PRIMARY KEY (AccusedID),
    CONSTRAINT fk_accused_fir FOREIGN KEY (DR_NO)
        REFERENCES FIR (DR_NO)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT chk_accused_age CHECK (Age >= 0 AND Age <= 125),
    CONSTRAINT chk_accused_gender CHECK (Gender IN ('M', 'F', 'X'))
) ENGINE=InnoDB;


-- Table 11: Court
-- Judicial courts handling formal criminal proceedings

CREATE TABLE Court (
    CourtID INT NOT NULL AUTO_INCREMENT,
    CourtName VARCHAR(100) NOT NULL,
    Address VARCHAR(200) NULL,
    Jurisdiction VARCHAR(100) NULL,
    CONSTRAINT pk_court PRIMARY KEY (CourtID)
) ENGINE=InnoDB;


-- Table 12: CourtCase
-- Legal proceedings resulting from formal charge/arrest
-- 1:1 relationship with FIR (one FIR results in at most one prosecuted CourtCase)

CREATE TABLE CourtCase (
    CaseID INT NOT NULL AUTO_INCREMENT,
    CaseNo VARCHAR(30) NOT NULL,
    FilingDate DATE NOT NULL,
    Verdict VARCHAR(60) NULL,
    VerdictDate DATE NULL,
    DR_NO VARCHAR(20) NOT NULL,
    CourtID INT NOT NULL,
    AccusedID INT NULL,
    CONSTRAINT pk_courtcase PRIMARY KEY (CaseID),
    CONSTRAINT uq_courtcase_caseno UNIQUE (CaseNo),
    CONSTRAINT uq_courtcase_drno UNIQUE (DR_NO),
    CONSTRAINT fk_courtcase_fir FOREIGN KEY (DR_NO)
        REFERENCES FIR (DR_NO)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_courtcase_court FOREIGN KEY (CourtID)
        REFERENCES Court (CourtID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_courtcase_accused FOREIGN KEY (AccusedID)
        REFERENCES Accused (AccusedID)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_courtcase_dates CHECK (VerdictDate IS NULL OR VerdictDate >= FilingDate)
) ENGINE=InnoDB;


-- Table 13: CrimeAuditLog (Trigger Support & Audit Trail)
-- Captures state transitions and changes on critical FIR records

CREATE TABLE CrimeAuditLog (
    LogID INT NOT NULL AUTO_INCREMENT,
    DR_NO VARCHAR(20) NOT NULL,
    OldStatus VARCHAR(10) NULL,
    NewStatus VARCHAR(10) NOT NULL,
    ChangedBy VARCHAR(100) NOT NULL,
    ChangedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ActionDesc VARCHAR(255) NOT NULL,
    CONSTRAINT pk_crimeauditlog PRIMARY KEY (LogID)
) ENGINE=InnoDB;

-- Verification query
SELECT 'Database crpsms_db instantiated successfully with 13 tables.' AS Status;
