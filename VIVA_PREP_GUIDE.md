# CRPSMS — Technical Viva Defense & Oral Q&A Guide
## TAE 2 DBMS Viva Preparation for Gaurav Singh (P15)

This guide provides precise, high-scoring answers to questions the faculty evaluation panel (Mr. Chinmay Mukim & Dr. Deepika Ajalkar) will ask during your 2-minute viva slot.

---

## 1. Normalization & Schema Validation (CO2 / BL3)

### Q1: Why did you split the raw 28-column dataset into 12 tables? How did you justify 3NF?
**Answer:**
> "The raw LAPD dataset (2nrs-mtv8) was a single flat unnormalized table containing multi-valued attributes, repeating columns, and transitive dependencies.
> 1. **1NF:** The raw dataset stored four separate crime code columns (`Crm_Cd_1` through `Crm_Cd_4`). This broke atomicity. I resolved this by introducing the junction table `FIR_CrimeType(DR_NO, Crm_Cd)` with a composite primary key.
> 2. **2NF:** In `FIR_CrimeType`, crime description depended solely on `Crm_Cd`, not the full composite key. I removed this partial dependency into the `CrimeType` table. Similarly, premises, weapons, and status descriptions were isolated into their own lookup tables.
> 3. **3NF:** In the main incident table, station name (`AREA_NAME`) functionally depended on station code (`AREA`), which was a non-prime attribute. This formed a transitive dependency `DR_NO -> AREA -> AREA_NAME`. I decomposed this by establishing `PoliceStation(AREA, AREA_NAME)`.
> In addition, to support the full operational lifecycle beyond passive logging, I created `Officer`, `Victim`, `Accused`, `Court`, and `CourtCase` tables."

### Q2: Is your schema in BCNF (Boyce-Codd Normal Form)?
**Answer:**
> "Yes. A relation is in BCNF if for every functional dependency $X \rightarrow Y$, the determinant $X$ is a superkey. In our schema:
> - In `PoliceStation`, `AREA` and `AREA_NAME` are both candidate keys (one PK, one UNIQUE).
> - In `Officer`, `OfficerID` is PK and `BadgeNo` is UNIQUE.
> - In `CourtCase`, `CaseID` is PK, `CaseNo` is UNIQUE, and `DR_NO` is UNIQUE (1:1 with FIR).
> There are no non-trivial functional dependencies where the determinant is not a superkey, ensuring both 3NF and BCNF compliance with lossless joins."

### Q3: What Foreign Key Cascade actions did you choose and why?
**Answer:**
> "- **ON UPDATE CASCADE:** Applied across all foreign keys so that if an identifier (such as `AREA` or `DR_NO`) is corrected, all referring child tuples automatically synchronize without data divergence.
> - **ON DELETE CASCADE:** Used strictly for child entities that have existence dependency on the parent incident (`Victim`, `Accused`, `FIR_CrimeType`). If an FIR record is purged, its associated victim and accused charges are safely deleted.
> - **ON DELETE RESTRICT:** Used for reference master entities (`PoliceStation`, `Officer`, `CrimeType`, `Court`). An officer or police station cannot be deleted if active crime records are linked to them, preventing orphan records.
> - **ON DELETE SET NULL:** Applied on optional circumstantial attributes (`Weapon_Used_Cd`, `Premis_Cd`) so deleting a weapon type does not destroy the incident record."

---

## 2. Transaction Management & ACID Compliance (CO2 / BL3)

### Q4: How does your Stored Procedure `sp_RegisterNewFIR` enforce ACID properties?
**Answer:**
> "Registering an incident requires insertions into three distinct tables: `FIR`, `FIR_CrimeType`, and `Victim`.
> - **Atomicity:** We wrap these operations in a single transaction block (`START TRANSACTION` ... `COMMIT`). If an insertion fails (e.g., check constraint violation on `Vict_Age` or duplicate key), MySQL hits our `DECLARE EXIT HANDLER FOR SQLEXCEPTION`, which immediately issues a `ROLLBACK`. Either all three rows persist, or none do.
> - **Consistency:** Enforces integrity rules: occurrence dates cannot be in the future, reporting date must be $\ge$ occurrence date (`CHECK (Date_Rptd >= Date_Occ)`), and foreign keys must exist.
> - **Isolation:** Handled by MySQL InnoDB's default `REPEATABLE READ` isolation level using Multi-Version Concurrency Control (MVCC) and gap/next-key locking. Other concurrent sessions cannot observe uncommitted FIRs (prevents Dirty Reads).
> - **Durability:** Upon `COMMIT`, InnoDB flushes transaction log buffers to the Write-Ahead Redo Log (`ib_logfile`), ensuring persistence across hardware or server failures."

### Q5: What is the difference between a Stored Procedure and a Function in MySQL?
**Answer:**
> "- A **Stored Procedure** is designed for operational business logic, can execute DML transactions (`START TRANSACTION`, `COMMIT`, `ROLLBACK`), can have multiple `IN`, `OUT`, and `INOUT` parameters, and is invoked using `CALL procedure_name()`.
> - A **Stored Function** must compute and return a single deterministic value using the `RETURN` keyword, cannot perform transaction management (`COMMIT`/`ROLLBACK`), and can be embedded directly within `SELECT` or `WHERE` expressions."

---

## 3. Indexing Mechanics & Query Optimization (CO3 / BL4)

### Q6: Explain what happened in your EXPLAIN benchmark before and after adding the composite index.
**Answer:**
> "In **Benchmark 1**, we filtered incidents by date range (`Date_Occ BETWEEN '2022-01-01' AND '2023-06-30'`) and station (`AREA IN (1, 2, 3, 6)`), joined with `FIR_CrimeType`.
> - **Before Index:**
>   - MySQL performed a **Full Table Scan** (`type: ALL`).
>   - It examined all 150 rows in `FIR`, and the `Extra` column showed `Using where; Using temporary; Using filesort`.
> - **Action:** We created a composite B-Tree index: `CREATE INDEX idx_fir_date_area ON FIR(Date_Occ, AREA);`
> - **After Index:**
>   - Access type improved from `ALL` to **`range` / `ref`**.
>   - Rows examined dropped from 150 to ~18 index records (~88% reduction in I/O!).
>   - The `Extra` column showed `Using index condition`, eliminating filesort overhead."

### Q7: What is the difference between a Clustered Index and a Secondary Index in InnoDB?
**Answer:**
> "- **Clustered Index:** In InnoDB, every table has exactly one clustered index, which is the Primary Key (e.g., `DR_NO`). The actual table row data is physically stored in the leaf pages of this B+ Tree. Looking up by PK requires traversing the tree once directly to the data page.
> - **Secondary (Non-Primary) Index:** Any non-primary index (like `idx_fir_date_area` or `idx_accused_arrestdate`). Its leaf pages do *not* contain the whole row; they store the indexed column values plus the Primary Key pointer (`DR_NO`).
> - When a query cannot be satisfied solely from the secondary index (index covering), MySQL does a secondary index search followed by a **bookmark lookup** (clustered index traversal) to fetch the rest of the columns."

### Q8: What is the trade-off of adding indexes? Why not index every column?
**Answer:**
> "While indexes significantly speed up `SELECT` read queries from $O(N)$ sequential scan to $O(\log N)$ B-Tree search, they introduce a write penalty:
> 1. **Write Overhead:** Every `INSERT`, `UPDATE`, or `DELETE` requires updating every secondary index tree, which can cause B-Tree page splits, rebalancing, and lock contention.
> 2. **Storage Consumption:** Index trees consume memory in the InnoDB Buffer Pool and disk space.
> Therefore, we index only high-cardinality columns frequently present in `WHERE`, `JOIN ON`, and `ORDER BY` clauses."

---

## 4. Trigger Logic & Dynamic Auditing (CO2 / BL3)

### Q9: Explain the logic of your triggers (`trg_FIR_Status_Audit` and `trg_Accused_AutoUpdate_FIRStatus`).
**Answer:**
> "- **Trigger 1 (`trg_FIR_Status_Audit`):** An `AFTER UPDATE ON FIR` trigger. It checks if `OLD.Status <> NEW.Status`. When true, it automatically inserts an immutable record into `CrimeAuditLog` capturing `DR_NO`, `OldStatus`, `NewStatus`, the active user (`CURRENT_USER()`), and timestamp (`NOW()`). This provides non-repudiation and chain of custody.
> - **Trigger 2 (`trg_Accused_AutoUpdate_FIRStatus`):** An `AFTER INSERT ON Accused` trigger. When a suspect with a valid `ArrestDate` is registered, it automatically executes `UPDATE FIR SET Status = 'AA' WHERE DR_NO = NEW.DR_NO AND Status = 'IC'`.
> - **Cascading Event:** What's powerful is that when Trigger 2 updates `FIR`, it automatically causes Trigger 1 to fire, logging the status change into `CrimeAuditLog` seamlessly!"

### Q10: What is the difference between `BEFORE` and `AFTER` triggers?
**Answer:**
> "- **`BEFORE` Triggers:** Fire *prior* to writing the row to disk. They are used for data validation, sanitization, or modifying column values using `SET NEW.column = value`.
> - **`AFTER` Triggers:** Fire *after* the change is written and verified against table constraints. They are used when the action requires the permanent row or primary key (e.g. `LAST_INSERT_ID()`), or for updating other tables and audit logging where you want to ensure the base operation succeeded."

---

## 5. Correlated Subqueries & Views (CO2 / BL3)

### Q11: How does a Correlated Subquery differ from a regular subquery?
**Answer:**
> "- A **regular (uncorrelated) subquery** is independent of the outer query; it executes once, and its scalar or list result is substituted into the outer query.
> - A **correlated subquery** depends on values from the current candidate row of the outer query (in our query: `WHERE f_inner.AREA = f.AREA`). As a result, the inner query is evaluated repeatedly for each outer row, computing dynamic station-level averages in real time."

### Q12: Why did you create Views? Do they store physical data?
**Answer:**
> "- In MySQL, standard views (`CREATE VIEW`) are virtual tables; they do *not* store physical copies of data on disk. Instead, the query definition is stored in the data dictionary, and MySQL merges the view query with the invoking query at execution time.
> - We created two views:
>   1. `vw_StationCrimePerformance`: Summarizes crime volumes, assigned staffing, and clearance percentages for police executives.
>   2. `vw_CourtCaseBacklogSummary`: Automatically computes `Days_In_Litigation` via `DATEDIFF()` to flag judicial delays.
> - Views provide security (data hiding / abstraction), simplify complex multi-table join syntax for client applications, and ensure uniform business metrics across departments."
