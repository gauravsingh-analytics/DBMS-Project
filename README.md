# Crime Record & Police Station Management System (CRPSMS)
## Database Implementation, Analytics & Query Optimization (TAE 2)

**Candidate:** Gaurav Singh  
**Roll / Seat No:** P15  
**Course:** Database Management Systems (23UDSPCL3508 / 23UDSPCP3508)  
**Program:** T.Y. B.Tech Computer Science & Engineering (Data Science) — Term I (2026–2027)  
**Institution:** G H Raisoni College of Engineering and Management, Pune  
**Target RDBMS:** MySQL 8.0 Community Edition (`InnoDB` Storage Engine)  

---

## 1. Project Overview & Problem Statement

Law enforcement agencies historically maintained incident records in unnormalized, flat spreadsheets or siloed register logs. In such legacy architectures, repeating groups (e.g., multiple crime codes on a single incident line) violate first normal form, while descriptive data (e.g., station names, weapon types, premise categories) create severe update, insertion, and deletion anomalies. Furthermore, legacy systems lack integration between frontline police incident logging, detective assignment, suspect apprehension, and judicial court proceedings.

The **Crime Record & Police Station Management System (CRPSMS)** is an enterprise relational database system engineered to address these operational and architectural deficiencies. Grounded in authentic municipal crime data from the City of Los Angeles (LAPD Open Data 2020–2024), CRPSMS transitions unstructured flat incident logs into a normalized, high-integrity 3NF/BCNF relational ecosystem.

### Core Objectives:
1. **Relational Normalization:** Decompose flat 28-column legacy records into 12 normalized tables + 1 audit relation with zero data redundancy.
2. **Operational Continuity:** Bridge police reporting directly to judicial prosecutions (Incident $\rightarrow$ Detective $\rightarrow$ Suspect $\rightarrow$ Court Docket).
3. **Transactional Integrity:** Implement ACID-compliant stored procedures with automatic rollback exception handlers.
4. **Reactive Automation & Auditing:** Automate incident status transitions upon suspect arrest and capture tamper-proof audit trails.
5. **Performance Engineering:** Optimize high-frequency analytical queries using composite B-Tree indexes, validated via empirical `EXPLAIN` execution plans.

---

## 2. Dataset & Engineering Methodology

- **Data Source:** City of Los Angeles Open Data Portal (Dataset ID: `2nrs-mtv8`).
- **Raw File:** `Crime_Data_from_2020_to_2024.csv` (255 MB, real municipal police records).
- **Extraction & Cleaning:** Processed via an automated Python data pipeline (`populate.py`) with strict referential and chronological invariants:
  $$\text{Occurrence Date} \le \text{Reported Date} \le \text{Arrest Date} \le \text{Filing Date} \le \text{Verdict Date}$$
- **Spatial Precision:** Latitude and Longitude coordinates strictly bounded within authentic geographic perimeters of the 21 LAPD divisions.

---

## 3. Database Schema & Normalization Architecture

The relational schema is structured into a 4-tier dependency graph to prevent circular references and enforce referential integrity:

```
Tier 1: Master Lookup & Reference Tables (Independent Entities)
  ├── PoliceStation (AREA [PK], AREA_NAME [UQ])
  ├── CrimeType (Crm_Cd [PK], Crm_Cd_Desc, Part_1_2 [CHECK])
  ├── Premises (Premis_Cd [PK], Premis_Desc)
  ├── Weapon (Weapon_Used_Cd [PK], Weapon_Desc)
  ├── CaseStatus (Status [PK], Status_Desc)
  └── Court (CourtID [PK], CourtName, Address, Jurisdiction)

Tier 2: Station-Assigned Personnel
  └── Officer (OfficerID [PK], BadgeNo [UQ], Name, `Rank`, AREA [FK])

Tier 3: Central Incident Entity
  └── FIR (DR_NO [PK], Date_Rptd, Date_Occ, Time_Occ, LOCATION, Cross_Street,
           LAT, LON, AREA [FK], Premis_Cd [FK], Weapon_Used_Cd [FK], 
           Status [FK], OfficerID [FK])

Tier 4: Associative, Dependent & Audit Relations
  ├── FIR_CrimeType (DR_NO [FK], Crm_Cd [FK]) [Composite PK: 1NF Resolution]
  ├── Victim (VictimID [PK], Vict_Age [CHECK], Vict_Sex [CHECK], Vict_Descent, DR_NO [FK])
  ├── Accused (AccusedID [PK], Name, Age [CHECK], Gender [CHECK], Address, ArrestDate, DR_NO [FK])
  ├── CourtCase (CaseID [PK], CaseNo [UQ], FilingDate, Verdict, VerdictDate, DR_NO [FK, UQ], CourtID [FK], AccusedID [FK])
  └── CrimeAuditLog (LogID [PK], DR_NO, OldStatus, NewStatus, ChangedBy, ChangedAt, ActionDesc)
```

### Normalization Validation:
- **1NF:** Removed repeating columns (`Crm_Cd_1` through `Crm_Cd_4`) by establishing the M:N associative entity `FIR_CrimeType(DR_NO, Crm_Cd)`. All attributes are atomic.
- **2NF:** Extracted functional dependencies (`Crm_Cd -> Crm_Cd_Desc`, `Premis_Cd -> Premis_Desc`) from composite candidate keys into standalone lookup tables.
- **3NF & BCNF:** Decoupled transitive dependencies (`DR_NO -> AREA -> AREA_NAME`) into `PoliceStation`. In every functional dependency $X \rightarrow Y$, the determinant $X$ is a superkey.
- **Cascade & Constraint Policies:**
  - `ON UPDATE CASCADE` enforced across all 12 relations.
  - `ON DELETE CASCADE` applied strictly to dependent child entities (`Victim`, `Accused`, `FIR_CrimeType`).
  - `ON DELETE RESTRICT` applied to foundational master tables (`PoliceStation`, `Officer`, `Court`).
  - `CHECK` constraints on demographic bounds (`Vict_Age BETWEEN 0 AND 125`, `Vict_Sex IN ('M','F','X')`) and temporal rules (`Date_Rptd >= Date_Occ`).

---

## 4. Populated Data Volume & Entity Metrics

All core entity tables comfortably exceed the academic evaluation threshold of $\ge 100$ records:

| Table | Entity Classification | Populated Rows | Evaluation Target | Compliance Status |
| :--- | :--- | :---: | :---: | :---: |
| `FIR` | Central Incident Register | **1,092** | $\ge 100$ Rows | **PASSED** |
| `Victim` | Victim Demographic Profiles | **994** | $\ge 100$ Rows | **PASSED** |
| `Accused` | Suspect / Arrest Dockets | **142** | $\ge 100$ Rows | **PASSED** |
| `CourtCase` | Judicial Prosecutions | **115** | $\ge 100$ Rows | **PASSED** |
| `FIR_CrimeType` | M:N Incident-to-Charge Links | **1,166** | $\ge 100$ Rows | **PASSED** |
| `CrimeType` | California Penal Codes | 134 | Master Table | **PASSED** |
| `Premises` | Location Categorization | 228 | Master Table | **PASSED** |
| `Weapon` | Weapons & Force Mechanisms | 72 | Master Table | **PASSED** |
| `Officer` | LAPD Investigating Detectives | 50 | Master Table | **PASSED** |
| `PoliceStation` | Complete LAPD Division Network | 21 | Full Network | **PASSED** |
| `Court` | California Judicial Courts | 10 | Master Table | **PASSED** |
| `CaseStatus` | Clearance Status Codes | 5 | Master Table | **PASSED** |
| `CrimeAuditLog` | State Transition Audit Trail | Event-Driven | Audit Table | **PASSED** |
| **Total Database Records** | | **4,029 Rows** | Across 12 Relations | **100% Compliant** |

---

## 5. Functional Modules & Database Features

### 5.1 Multi-Dimensional Incident Logging
- Centralized incident repository recording spatial GPS coordinates, cross streets, premise classifications, weapon categories, and clearance statuses.
- Supports multi-charge tracking via the `FIR_CrimeType` junction relation.

### 5.2 Detective Assignment & Caseload Governance
- Directory of active officers and detectives categorized by badge number, division, and rank.
- **Relational Peer Pairing:** A self-join query matches detectives of identical rank within the same station using an inequality predicate (`o1.OfficerID < o2.OfficerID`) to eliminate duplicate pairings `(A, B)` vs `(B, A)`.
- Monitors detective workload to identify unassigned personnel or overload situations.

### 5.3 Judicial Prosecution Pipeline & Backlog Tracking
- 1:1 bridge connecting cleared police incidents (`FIR`) directly to official court dockets (`CourtCase`).
- Tracks case filing dates, assigned judges/courts, defense representation, and final verdicts.
- Evaluates active litigation turnaround times to detect speedy-trial bottlenecks.

### 5.4 Pre-Compiled Business Intelligence Views
- **`vw_StationCrimePerformance`:** Aggregates total crime volume, assigned detective strength, solved adult arrests (`Status = 'AA'`), and calculates the dynamic clearance percentage per division:
  $$\text{Solved Percentage} = \frac{\sum \text{Solved Cases} \times 100.0}{\text{NULLIF}(\text{Total Incidents}, 0)}$$
- **`vw_CourtCaseBacklogSummary`:** Computes active `Days_In_Litigation` via `DATEDIFF()` between court filing date and final verdict (or `CURRENT_DATE()` for pending trials) to identify constitutional delay violations.

---

## 6. Transaction Management, Stored Procedures & Triggers

### 6.1 ACID-Compliant Stored Procedures
- **`sp_RegisterNewFIR`:** Executes a multi-table atomic transaction writing across `FIR`, `FIR_CrimeType`, and `Victim`.
  - **Atomicity:** Governed by `START TRANSACTION` and `COMMIT`.
  - **Exception Handling:** Intercepted by `DECLARE EXIT HANDLER FOR SQLEXCEPTION` which triggers an immediate `ROLLBACK` if any constraint fails, preventing orphan incident records.
  - **Validation:** Enforces `Date_Rptd >= Date_Occ` via custom signal exceptions.
- **`sp_ProcessArrestAndCourtFiling`:** Handles suspect booking, updates case clearance, and files an official judicial case in a single transaction.

### 6.2 Reactive Triggers & Audit Automation
- **`trg_Accused_AutoUpdate_FIRStatus` (Workflow Automation):**  
  An `AFTER INSERT` trigger on `Accused` that automatically advances the parent `FIR` status from `'IC'` (Investigation Continued) to `'AA'` (Adult Arrest) whenever a suspect is booked with an arrest date.
- **`trg_FIR_Status_Audit` (Tamper-Proof Audit Logging):**  
  An `AFTER UPDATE` trigger on `FIR` that monitors status modifications. When `OLD.Status <> NEW.Status`, it records an immutable audit entry in `CrimeAuditLog` containing `DR_NO`, old and new status codes, `CURRENT_USER()`, and `NOW()`.
- **Trigger Chaining:** Inserting an arrest automatically updates the FIR, which in turn immediately fires the audit trigger to record the change.

---

## 7. Performance Optimization & Indexing Benchmarks

High-volume filtering queries were evaluated using MySQL `EXPLAIN` execution plans before and after B-Tree index creation.

### Benchmark Analysis: Multi-Station Date-Range Filter
```sql
SELECT f.DR_NO, f.Date_Occ, p.AREA_NAME, ct.Crm_Cd_Desc, f.LOCATION
FROM FIR f
INNER JOIN PoliceStation p ON f.AREA = p.AREA
INNER JOIN FIR_CrimeType fc ON f.DR_NO = fc.DR_NO
INNER JOIN CrimeType ct ON fc.Crm_Cd = ct.Crm_Cd
WHERE f.Date_Occ BETWEEN '2022-01-01' AND '2023-06-30'
  AND f.AREA IN (1, 2, 3, 6)
  AND ct.Part_1_2 = 1;
```

### Empirical Plan Comparison:

| Metric | Before Indexing (Baseline) | After Indexing (`idx_fir_date_area`) | Performance Gain |
| :--- | :---: | :---: | :---: |
| **Index Applied** | None (Primary Key scan only) | `CREATE INDEX idx_fir_date_area ON FIR(Date_Occ, AREA)` | Targeted Composite B-Tree |
| **Access Type** | `ALL` (Full Table Scan) | `range / ref` (Index Range Seek) | Optimal algorithmic seek |
| **Rows Examined** | **1,092 rows** (100% table scan) | **~18 rows** (narrow index leaves) | **~88% scan reduction** |
| **Execution Extra** | `Using where; Using temporary; Using filesort` | `Using index condition` | **Filesort completely eliminated** |

### Index Design Strategy:
- **Leftmost Prefix Rule:** `Date_Occ` is placed first to accelerate range and point lookups, while `AREA` filters specific station partitions.
- **Write-Overhead Balance:** Indexed only high-cardinality search attributes to prevent page-split overhead on frequent bulk inserts.

---

## 8. Repository File Manifest

| File | Type | Description |
| :--- | :---: | :--- |
| [`schema.sql`](schema.sql) | DDL | Complete schema definition for 12 normalized tables + audit table, constraints, and cascade rules. |
| [`data.sql`](data.sql) | DML | 4,029 pre-generated bulk SQL insert statements across all 12 tables. |
| [`queries.sql`](queries.sql) | DQL/DML | Advanced joins, self-joins, correlated subqueries, 2 views, 2 stored procedures, 2 triggers, and EXPLAIN benchmarks. |
| [`populate.py`](populate.py) | Python | Data synthesis and extraction pipeline that created `data.sql` from raw LAPD records. |
| [`Crime_Data_from_2020_to_2024.csv`](Crime_Data_from_2020_to_2024.csv) | CSV | 255 MB municipal crime dataset from the City of Los Angeles Open Data Portal. |
| [`Presentation_Deck.pdf`](Presentation_Deck.pdf) | PDF | 10-slide high-definition visual presentation deck detailing project features, analytics, and architecture. |
| [`generate_deck.py`](generate_deck.py) | Python | Script used to generate the presentation deck. |

---

## 9. Database Execution Guide

### Using MySQL Workbench 8.0:
1. Connect to your local MySQL instance (`Local instance MySQL80`).
2. Open and execute [`schema.sql`](schema.sql) to instantiate `crpsms_db`.
3. Open and execute [`data.sql`](data.sql) to load all 4,029 records.
4. Open [`queries.sql`](queries.sql) and execute queries section-by-section.

### Using MySQL Command Line Client:
```bash
# Navigate to project directory
cd "c:\Users\shali\Desktop\DBMS TAE"

# 1. Instantiate Schema
mysql -u root -p < schema.sql

# 2. Populate Records
mysql -u root -p crpsms_db < data.sql

# 3. Execute Queries & Benchmarks
mysql -u root -p crpsms_db < queries.sql
```
