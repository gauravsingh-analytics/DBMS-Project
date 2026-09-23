# Crime Record & Police Station Management System (CRPSMS)
## TAE 2: Database Implementation, Performance Optimization & Presentation

**Candidate:** Gaurav Singh  
**Roll / Seat No:** P15  
**Course:** Database Management Systems (23UDSPCL3508 / 23UDSPCP3508)  
**Program:** T.Y. B.Tech Computer Science & Engineering (Data Science) — Term I (2026–2027)  
**Institution:** G H Raisoni College of Engineering and Management, Pune  
**Target RDBMS:** MySQL 8.0 (InnoDB Storage Engine)  
**Evaluation:** 20 Marks (10 Marks SQL & DDL Implementation + 10 Marks Optimization & Live Defense)  

---

## 1. Repository & File Manifest

| File | Purpose | Description |
| :--- | :--- | :--- |
| [`schema.sql`](schema.sql) | **DDL Schema Instantiation** | Complete database schema script defining 12 3NF normalized core tables + 1 audit log (`CrimeAuditLog`), primary keys, foreign keys with cascade policies, UNIQUE, and CHECK constraints. |
| [`populate.py`](populate.py) | **Synthetic Data Generator** | Python pipeline extracting and synthesizing realistic, chronologically coherent records from LAPD Open Data (`Crime_Data_from_2020_to_2024.csv`). |
| [`data.sql`](data.sql) | **DML Insert Scripts** | Pre-generated bulk SQL insert statements containing **4,029 total records** across all 12 tables (all core entities comfortably exceed the $\ge 100$ rows requirement). |
| [`queries.sql`](queries.sql) | **Advanced SQL & Benchmarking** | Multi-table joins (inner, outer, self), correlated subqueries, 2 business views, 2 ACID stored procedures, 2 event triggers, and before-and-after EXPLAIN benchmarks. |
| [`generate_deck.py`](generate_deck.py) | **Slide Deck Generator** | Python script utilizing Matplotlib to generate the clean, query-free 10-slide executive presentation PDF. |
| [`Presentation_Deck.pdf`](Presentation_Deck.pdf) | **Presentation Deck (PDF)** | 10-slide high-definition visual presentation deck focused on architecture, features, analytics, and outcomes. |
| [`VIVA_PREP_GUIDE.md`](VIVA_PREP_GUIDE.md) | **Technical Viva Defense Guide** | In-depth technical Q&A covering 3NF/BCNF normalization, ACID transaction mechanics, B-Tree index structures, and EXPLAIN plans. |

---

## 2. Table Summary & Record Volume Certification

All core entity tables comfortably exceed the mandatory **100+ rows** threshold with real data extracted from the LAPD dataset:

| Table | Entity Category | Total Records | Faculty Target | Compliance Status |
| :--- | :--- | :---: | :---: | :---: |
| `FIR` | **Central Incident Records** | **1,092** | **≥ 100 Rows** | **PASSED** |
| `Victim` | **Victim Demographics** | **994** | **≥ 100 Rows** | **PASSED** |
| `Accused` | **Suspect / Arrest Dockets** | **142** | **≥ 100 Rows** | **PASSED** |
| `CourtCase` | **Judicial Prosecutions** | **115** | **≥ 100 Rows** | **PASSED** |
| `FIR_CrimeType` | **M:N Charge Links** | **1,166** | **≥ 100 Rows** | **PASSED** |
| `CrimeType` | Penal Code Classifications | 134 | Master Table | **PASSED** |
| `Premises` | Location Categorization | 228 | Master Table | **PASSED** |
| `Weapon` | Weapons / Force Codes | 72 | Master Table | **PASSED** |
| `Officer` | Investigating Detectives | 50 | Master Table | **PASSED** |
| `PoliceStation` | LAPD Divisions | 21 | Full Division Network | **PASSED** |
| `Court` | California Judicial Courts | 10 | Master Table | **PASSED** |
| `CaseStatus` | Clearance Status Codes | 5 | Master Table | **PASSED** |
| `CrimeAuditLog` | Dynamic State Transitions | Event-Driven | Audit Table | **PASSED** |
| **Total Database Records** | | **4,029 Rows** | Across 12 Relations | **Fully Compliant** |

---

## 3. Relational Schema Architecture (12 Tables + Audit Relation)

The schema is organized into a clean 4-tier dependency structure to enforce data integrity:

```
Level 1: Master Lookups & Independent Entities
  ├── PoliceStation (AREA PK, AREA_NAME UQ)
  ├── CrimeType (Crm_Cd PK, Part_1_2 CHECK)
  ├── Premises (Premis_Cd PK)
  ├── Weapon (Weapon_Used_Cd PK)
  ├── CaseStatus (Status PK)
  └── Court (CourtID PK)

Level 2: Station Assigned Personnel
  └── Officer (OfficerID PK, BadgeNo UQ, AREA FK)

Level 3: Central Incident Relation
  └── FIR (DR_NO PK, AREA FK, Premis FK, Weapon FK, Officer FK, Status FK)

Level 4: Dependent & Associative Entities
  ├── FIR_CrimeType (DR_NO FK, Crm_Cd FK) [Composite PK: 1NF Junction]
  ├── Victim (VictimID PK, DR_NO FK, Age/Sex CHECK)
  ├── Accused (AccusedID PK, DR_NO FK, Age/Gender CHECK)
  ├── CourtCase (CaseID PK, CaseNo UQ, DR_NO FK UQ, CourtID FK, AccusedID FK)
  └── CrimeAuditLog (LogID PK, DR_NO, OldStatus, NewStatus, ChangedBy, ChangedAt)
```

---

## 4. Step-by-Step Execution Guide

### Option A: Using MySQL Workbench 8.0 (Recommended for Live Demo)
1. Open **MySQL Workbench 8.0** and connect to your local MySQL instance (`Local instance MySQL80`).
2. Open and execute [`schema.sql`](schema.sql):
   - Click `File` -> `Open SQL Script...` -> select `schema.sql`.
   - Click the **Execute (Lightning icon)** to instantiate `crpsms_db`.
3. Open and execute [`data.sql`](data.sql):
   - Click `File` -> `Open SQL Script...` -> select `data.sql`.
   - Click **Execute** to populate all 4,029 records.
4. Open [`queries.sql`](queries.sql):
   - Highlight and execute queries section-by-section during your live demonstration.

### Option B: Using Windows Terminal / PowerShell
```powershell
# Navigate to the project directory
cd "c:\Users\shali\Desktop\DBMS TAE"

# 1. Execute schema creation DDL
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p < schema.sql

# 2. Populate 4,029 records
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p crpsms_db < data.sql

# 3. Run advanced queries, procedures, triggers & benchmarks
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p crpsms_db < queries.sql
```

---

## 5. 8-Minute Live Demonstration & Viva Defense Script

| Timing | Phase / Action | Key Speaking Points |
| :---: | :--- | :--- |
| **0:00 - 1:00** | **Slide Deck (Slides 1–4)** | • Introduce CRPSMS domain, LAPD real-world origin, and 12-table 3NF schema.<br>• Highlight features: GPS incident logging, detective pairing, prosecution pipeline. |
| **1:00 - 2:00** | **Slide Deck (Slides 5–10)** | • Present data volume (4,029 rows), business analytics (clearance rates, litigation duration), and EXPLAIN benchmark (88% row scan reduction).<br>• Transition smoothly to MySQL Workbench. |
| **2:00 - 3:00** | **Workbench: Record Counts** | • Run verification query: show `FIR` (1,092), `Victim` (994), `Accused` (142), `CourtCase` (115).<br>• Demonstrates full compliance with the 100+ rows mandate. |
| **3:00 - 4:15** | **Workbench: Joins & Subqueries** | • Run **5-Table Join** showing complete incident dossier.<br>• Run **Self-Join** pairing peer detectives by station and rank.<br>• Run **Correlated Subquery** evaluating victim age against dynamic station averages. |
| **4:15 - 5:15** | **Workbench: Views** | • Query `vw_StationCrimePerformance` (clearance rate %, solved cases).<br>• Query `vw_CourtCaseBacklogSummary` (tracks `Days_In_Litigation` via `DATEDIFF`). |
| **5:15 - 6:30** | **Workbench: Procedures & Triggers** | • Call `sp_RegisterNewFIR(...)` (demonstrates atomic transaction with `COMMIT`).<br>• Call `sp_ProcessArrestAndCourtFiling(...)` (Trigger 2 updates FIR to `'AA'`).<br>• Query `CrimeAuditLog` to show the dynamic audit entry captured by Trigger 1! |
| **6:30 - 7:30** | **Workbench: EXPLAIN Optimization** | • Execute `EXPLAIN` before index (`type: ALL`, 1,092 rows scanned, `Using filesort`).<br>• Create composite index: `CREATE INDEX idx_fir_date_area ON FIR(Date_Occ, AREA);`<br>• Re-execute `EXPLAIN` (`type: range/ref`, scans only ~18 rows, filesort eliminated!). |
| **7:30 - 8:00** | **Conclusion & Transition** | Summarize database achievements and invite questions from the panel. |
| **8:00 - 10:00**| **Faculty Viva Defense (Q&A)** | Refer to [`VIVA_PREP_GUIDE.md`](VIVA_PREP_GUIDE.md) for quick-fire conceptual answers! |

---

## 6. Submission Checklist

- [x] **Strict Continuity:** Retains the exact CRPSMS domain, entities, and constraints approved in TAE 1.
- [x] **Data Volume:** 1,092 FIR, 994 Victim, 142 Accused, 115 CourtCase rows (all comfortably > 100 rows).
- [x] **`schema.sql`:** Complete DDL with PKs, FK cascades, UNIQUE, and CHECK constraints.
- [x] **`populate.py` & `data.sql`:** 4,029 realistic records extracted and synthesized from LAPD CSV data.
- [x] **`queries.sql`:** Joins, Self-Join, Correlated Subqueries, 2 Views, 2 Procedures, 2 Triggers, EXPLAIN benchmarks.
- [x] **`Presentation_Deck.pdf`:** 10-slide high-definition visual presentation deck focused on features and analytics.
- [x] **`VIVA_PREP_GUIDE.md`:** Comprehensive Q&A defense reference for faculty evaluation.
- [x] **Submission Ready:** Upload repository ZIP or GitHub link to the [Official Submission Form](https://forms.gle/gNqKA79iBZMmLxtV9).
