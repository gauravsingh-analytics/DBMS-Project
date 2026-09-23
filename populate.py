"""
Crime Record & Police Station Management System (CRPSMS)
Script: populate.py
Extracts real records from Crime_Data_from_2020_to_2024.csv and populates
12 3NF normalized tables exceeding the faculty requirement (>= 100 records per core entity).
Outputs data.sql for direct execution in MySQL 8.0.
"""

import os
import sys
import random
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

def escape_sql(val):
    if val is None or pd.isna(val):
        return "NULL"
    s = str(val).strip()
    s = s.replace("\\", "\\\\").replace("'", "''")
    return f"'{s}'"

def format_time_occ(time_val):
    if pd.isna(time_val):
        return "'00:00:00'"
    try:
        t = int(float(time_val))
        h = max(0, min(23, t // 100))
        m = max(0, min(59, t % 100))
        return f"'{h:02d}:{m:02d}:00'"
    except Exception:
        return "'12:00:00'"

def format_date(date_str):
    if pd.isna(date_str):
        return None
    try:
        # Standard LAPD format: MM/DD/YYYY HH:MM:SS AM/PM or MM/DD/YYYY
        dt = pd.to_datetime(date_str, format="%m/%d/%Y %I:%M:%S %p", errors="coerce")
        if pd.isna(dt):
            dt = pd.to_datetime(date_str, errors="coerce")
        if pd.isna(dt):
            return None
        return dt.strftime("%Y-%m-%d")
    except Exception:
        return None

def extract_and_generate_dataset(csv_path="Crime_Data_from_2020_to_2024.csv", sample_per_area=52):
    random.seed(42)
    np.random.seed(42)

    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"Dataset CSV not found at {csv_path}!")

    print(f"Reading dataset: {csv_path}...")
    usecols = [
        "DR_NO", "Date Rptd", "DATE OCC", "TIME OCC", "AREA", "AREA NAME", "Rpt Dist No",
        "Part 1-2", "Crm Cd", "Crm Cd Desc", "Vict Age", "Vict Sex", "Vict Descent",
        "Premis Cd", "Premis Desc", "Weapon Used Cd", "Weapon Desc", "Status", "Status Desc",
        "Crm Cd 1", "Crm Cd 2", "Crm Cd 3", "Crm Cd 4", "LOCATION", "Cross Street", "LAT", "LON"
    ]

    # Read initial 60,000 records to extract lookups and sample balanced records
    df = pd.read_csv(csv_path, nrows=65000, usecols=usecols)
    print(f"Loaded {len(df):,} raw records for parsing and extraction.")

    # 1. PoliceStation (21 LAPD Divisions)
    station_df = df[["AREA", "AREA NAME"]].dropna().drop_duplicates(subset=["AREA"]).sort_values("AREA")
    stations = [(int(row["AREA"]), str(row["AREA NAME"]).strip()) for _, row in station_df.iterrows()]
    print(f"Extracted {len(stations)} official LAPD Police Stations.")

    # 2. CaseStatus (Standard LAPD Clearance Codes)
    statuses = [
        ("IC", "Investigation Continued"),
        ("AA", "Adult Arrest"),
        ("AO", "Adult Other"),
        ("JA", "Juvenile Arrest"),
        ("JO", "Juvenile Other")
    ]

    # 3. CrimeType (Unique Crime classifications)
    ct_df = df[["Crm Cd", "Crm Cd Desc", "Part 1-2"]].dropna(subset=["Crm Cd", "Crm Cd Desc"]).drop_duplicates(subset=["Crm Cd"])
    crime_types_dict = {}
    for _, row in ct_df.iterrows():
        cd = int(row["Crm Cd"])
        desc = str(row["Crm Cd Desc"]).strip().replace("'", "''")
        part = int(row["Part 1-2"]) if row["Part 1-2"] in (1, 2) else 2
        crime_types_dict[cd] = (cd, desc, part)

    # Secondary crime codes may exist in Crm Cd 1..4 without standalone Crm Cd entry
    sec_cols = ["Crm Cd 1", "Crm Cd 2", "Crm Cd 3", "Crm Cd 4"]
    for col in sec_cols:
        for val in df[col].dropna().unique():
            cd = int(val)
            if cd not in crime_types_dict:
                crime_types_dict[cd] = (cd, f"ANCILLARY OFFENSE CODE {cd}", 2)

    crime_types = sorted(crime_types_dict.values(), key=lambda x: x[0])
    print(f"Extracted {len(crime_types)} Crime Types.")

    # 4. Premises
    prem_df = df[["Premis Cd", "Premis Desc"]].dropna().drop_duplicates(subset=["Premis Cd"])
    premises_dict = {}
    for _, row in prem_df.iterrows():
        cd = int(row["Premis Cd"])
        desc = str(row["Premis Desc"]).strip().replace("'", "''")
        premises_dict[cd] = (cd, desc)
    premises = sorted(premises_dict.values(), key=lambda x: x[0])
    print(f"Extracted {len(premises)} Premises categories.")

    # 5. Weapon
    wp_df = df[["Weapon Used Cd", "Weapon Desc"]].dropna().drop_duplicates(subset=["Weapon Used Cd"])
    weapons_dict = {}
    for _, row in wp_df.iterrows():
        cd = int(row["Weapon Used Cd"])
        desc = str(row["Weapon Desc"]).strip().replace("'", "''")
        weapons_dict[cd] = (cd, desc)
    weapons = sorted(weapons_dict.values(), key=lambda x: x[0])
    print(f"Extracted {len(weapons)} Weapon / Force categories.")

    # 6. Courts (10 California Superior Courts)
    courts = [
        ("Clara Shortridge Foltz Criminal Justice Center", "210 W Temple St, Los Angeles, CA 90012", "Central District - Felony Trials"),
        ("Stanley Mosk Courthouse", "111 N Hill St, Los Angeles, CA 90012", "Central District - Civil & Administration"),
        ("Van Nuys Courthouse West", "14400 Erwin Street Mall, Van Nuys, CA 91401", "Van Nuys District - Criminal Division"),
        ("Airport Courthouse", "11701 S La Cienega Blvd, Los Angeles, CA 90045", "West District - Criminal Arraignments"),
        ("Compton Courthouse", "200 W Compton Blvd, Compton, CA 90220", "South Central District - Criminal"),
        ("Long Beach Courthouse (Gov. George Deukmejian)", "275 Magnolia Ave, Long Beach, CA 90802", "South District - Criminal & Traffic"),
        ("Pasadena Courthouse", "300 E Walnut St, Pasadena, CA 91101", "Northeast District - Criminal"),
        ("Torrance Courthouse", "825 Maple Ave, Torrance, CA 90503", "Southwest District - Criminal Division"),
        ("San Fernando Courthouse", "900 Third St, San Fernando, CA 91340", "North Valley District"),
        ("Metropolitan Courthouse", "1945 S Hill St, Los Angeles, CA 90007", "Traffic and Infractions")
    ]

    # 7. Officers (50 LAPD Officers distributed across 21 divisions)
    ranks = ["Police Officer II", "Police Officer III", "Detective I", "Detective II", "Detective III", "Sergeant I"]
    first_names = [
        "Michael", "David", "James", "Robert", "John", "Carlos", "Jose", "Maria", "Jennifer", "Sarah",
        "Christopher", "Daniel", "Matthew", "Anthony", "Mark", "Elizabeth", "Patricia", "Jessica", "Laura", "Kevin",
        "Brian", "Jason", "Marcus", "Elena", "Richard", "Thomas", "Steven", "Paul", "Kenneth", "Edward"
    ]
    last_names = [
        "Johnson", "Rodriguez", "Smith", "Martinez", "Hernandez", "Garcia", "Davis", "Miller", "Wilson", "Anderson",
        "Taylor", "Thomas", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White", "Harris",
        "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young", "Allen", "King", "Wright"
    ]

    officers = []
    officers_by_area = {st[0]: [] for st in stations}
    for i in range(1, 51):
        badge = f"LAPD-{31000 + i}"
        name = f"{random.choice(first_names)} {random.choice(last_names)}"
        rank = random.choice(ranks)
        area = ((i - 1) % 21) + 1
        officers.append((i, badge, name, rank, area))
        officers_by_area[area].append(i)

    # 8. Filter and Sample Real Incidents (FIR)
    # Ensure test DR_NO is not included so stored procedure test in queries.sql works smoothly
    df_clean = df[df["DR_NO"] != 200199999].copy()
    df_clean = df_clean[df_clean["Status"].isin(["IC", "AA", "AO", "JA", "JO"])]
    df_clean = df_clean.dropna(subset=["DR_NO", "Date Rptd", "DATE OCC", "AREA", "Crm Cd"])

    sampled_firs = []
    # Sample balanced set per area with guaranteed AA (Adult Arrest) records for Accused & CourtCase
    for area, group in df_clean.groupby("AREA"):
        aa_group = group[group["Status"] == "AA"]
        other_group = group[group["Status"] != "AA"]

        n_aa = min(len(aa_group), 7)
        n_other = min(len(other_group), sample_per_area - n_aa)

        sampled_firs.append(aa_group.head(n_aa))
        sampled_firs.append(other_group.head(n_other))

    fir_df = pd.concat(sampled_firs).drop_duplicates(subset=["DR_NO"]).reset_index(drop=True)
    print(f"Sampled {len(fir_df)} real incident records across all 21 divisions.")

    # Process FIR rows
    firs = []
    fir_crimes = []
    victims = []
    accused_list = []
    court_cases = []

    accused_first_names = [
        "Marcus", "Hector", "Dante", "Jamal", "Raymond", "Devon", "Enrique", "Trevon", "Jesse", "Damian",
        "Javier", "Ricardo", "Tyrone", "Salvador", "Derrick", "Arturo", "Malik", "Ramon", "Julio", "Corey",
        "Adriana", "Brenda", "Vanessa", "Destiny", "Crystal", "Monique", "Rosa", "Amber", "Tanya", "Bianca"
    ]
    accused_last_names = [
        "Morales", "Castillo", "Vargas", "Guzman", "Rios", "Mendez", "Navarro", "Salazar", "Delgado", "Guerrero",
        "Washington", "Banks", "Jefferson", "Hawkins", "Booker", "Cobb", "Glover", "Holloway", "Curry", "McDaniel"
    ]
    la_streets = [
        "S Main St", "S Broadway", "S Figueroa St", "E Olympic Blvd", "W 6th St",
        "Wilshire Blvd", "Sunset Blvd", "Hollywood Blvd", "Sepulveda Blvd", "Van Nuys Blvd"
    ]

    victim_id_counter = 1
    accused_id_counter = 1
    court_case_id_counter = 1

    for _, row in fir_df.iterrows():
        dr_no = str(row["DR_NO"]).strip()
        rpt_date_str = format_date(row["Date Rptd"])
        occ_date_str = format_date(row["DATE OCC"])
        
        # Enforce check constraint: Date_Rptd >= Date_Occ
        if rpt_date_str is None or occ_date_str is None:
            continue
        if rpt_date_str < occ_date_str:
            rpt_date_str = occ_date_str

        time_occ_str = format_time_occ(row["TIME OCC"])
        area = int(row["AREA"])

        location = escape_sql(row["LOCATION"]) if pd.notna(row["LOCATION"]) else "NULL"
        cross_st = escape_sql(row["Cross Street"]) if pd.notna(row["Cross Street"]) else "NULL"
        lat = round(float(row["LAT"]), 7) if pd.notna(row["LAT"]) else 0.0
        lon = round(float(row["LON"]), 7) if pd.notna(row["LON"]) else 0.0

        premis_cd = int(row["Premis Cd"]) if pd.notna(row["Premis Cd"]) and int(row["Premis Cd"]) in premises_dict else "NULL"
        weapon_cd = int(row["Weapon Used Cd"]) if pd.notna(row["Weapon Used Cd"]) and int(row["Weapon Used Cd"]) in weapons_dict else "NULL"
        status = str(row["Status"]).strip()

        # Officer assignment
        assigned_officers = officers_by_area.get(area, [1])
        officer_id = random.choice(assigned_officers) if assigned_officers else 1

        firs.append((
            dr_no, rpt_date_str, occ_date_str, time_occ_str,
            location, cross_st, lat, lon, area, premis_cd, weapon_cd, status, officer_id
        ))

        # 9. FIR_CrimeType (M:N junction)
        primary_crm = int(row["Crm Cd"])
        if primary_crm in crime_types_dict:
            fir_crimes.append((dr_no, primary_crm))

        for sec_col in sec_cols:
            if pd.notna(row[sec_col]):
                sec_cd = int(row[sec_col])
                if sec_cd in crime_types_dict and sec_cd != primary_crm:
                    if (dr_no, sec_cd) not in fir_crimes:
                        fir_crimes.append((dr_no, sec_cd))

        # 10. Victim
        # Validate CHECK constraints: Vict_Age >= 0 AND Vict_Age <= 125, Vict_Sex IN ('M', 'F', 'X')
        v_age = row["Vict Age"]
        v_sex = str(row["Vict Sex"]).strip() if pd.notna(row["Vict Sex"]) else None
        v_descent = str(row["Vict Descent"]).strip() if pd.notna(row["Vict Descent"]) else None

        valid_age = None
        if pd.notna(v_age):
            try:
                age_val = int(float(v_age))
                if 0 <= age_val <= 125:
                    valid_age = age_val
            except Exception:
                pass

        valid_sex = v_sex if v_sex in ("M", "F", "X") else None
        valid_descent = v_descent[0] if v_descent and len(v_descent) == 1 and v_descent != "-" else None

        # Insert victim if demographic info is present
        if valid_age is not None and valid_age > 0 or valid_sex is not None:
            age_sql = str(valid_age) if valid_age is not None else "NULL"
            sex_sql = f"'{valid_sex}'" if valid_sex else "NULL"
            desc_sql = f"'{valid_descent}'" if valid_descent else "NULL"
            victims.append((victim_id_counter, age_sql, sex_sql, desc_sql, dr_no))
            victim_id_counter += 1

        # 11. Accused (Generated for Adult Arrest 'AA' and Juvenile Arrest 'JA' cases)
        if status in ("AA", "JA"):
            acc_name = f"{random.choice(accused_first_names)} {random.choice(accused_last_names)}"
            acc_age = random.randint(18, 62) if status == "AA" else random.randint(15, 17)
            acc_gender = random.choice(["M", "M", "M", "F", "X"])
            acc_addr = f"{random.randint(100, 9900)} {random.choice(la_streets)}, Los Angeles, CA"

            # ArrestDate must be >= Date_Occ
            occ_dt = datetime.strptime(occ_date_str, "%Y-%m-%d")
            arrest_dt = occ_dt + timedelta(days=random.randint(0, 12))
            arrest_dt_str = arrest_dt.strftime("%Y-%m-%d")

            acc_id = accused_id_counter
            accused_list.append((acc_id, acc_name, acc_age, acc_gender, acc_addr, arrest_dt_str, dr_no))
            accused_id_counter += 1

            # 12. CourtCase (Generated for prosecution cases)
            if court_case_id_counter <= 115 and status == "AA":
                case_no = f"BA{arrest_dt.year}-{1000 + court_case_id_counter}"
                filing_dt = arrest_dt + timedelta(days=random.randint(2, 10))
                court_id = random.randint(1, len(courts))

                verdicts = [
                    "Guilty - Convicted",
                    "Plea Bargain Accepted",
                    "Acquitted",
                    "Dismissed - Lack of Evidence",
                    None,
                    None
                ]
                v_choice = random.choice(verdicts)
                if v_choice is not None:
                    verdict_dt = filing_dt + timedelta(days=random.randint(30, 200))
                    verdict_sql = f"'{v_choice}'"
                    verdict_dt_sql = f"'{verdict_dt.strftime('%Y-%m-%d')}'"
                else:
                    verdict_sql = "NULL"
                    verdict_dt_sql = "NULL"

                court_cases.append((
                    court_case_id_counter,
                    case_no,
                    filing_dt.strftime("%Y-%m-%d"),
                    verdict_sql,
                    verdict_dt_sql,
                    dr_no,
                    court_id,
                    acc_id
                ))
                court_case_id_counter += 1

    return {
        "stations": stations,
        "statuses": statuses,
        "crime_types": crime_types,
        "premises": premises,
        "weapons": weapons,
        "courts": courts,
        "officers": officers,
        "firs": firs,
        "fir_crimes": fir_crimes,
        "victims": victims,
        "accused": accused_list,
        "court_cases": court_cases
    }

def write_sql_file(data, output_path="data.sql"):
    print(f"Writing SQL statements to {output_path}...")
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("-- ==============================================================================\n")
        f.write("-- PROJECT: Crime Record & Police Station Management System (CRPSMS)\n")
        f.write("-- COMPONENT: data.sql (LAPD 2020-2024 Real Data Population)\n")
        f.write("-- COURSE: 23UDSPCL3508 / 23UDSPCP3508 - Database Management Systems (TAE 2)\n")
        f.write("-- STUDENT: Gaurav Singh (Roll / PRN: P15)\n")
        f.write("-- CLASS: T.Y. B.Tech CSE (Data Science) - Term I (2026-2027)\n")
        f.write("-- COLLEGE: G H Raisoni College of Engineering and Management, Pune\n")
        f.write("-- TARGET RDBMS: MySQL 8.0\n")
        f.write("-- ==============================================================================\n\n")
        f.write("USE crpsms_db;\n\n")
        f.write("SET FOREIGN_KEY_CHECKS = 0;\n\n")

        # 1. PoliceStation
        f.write(f"-- 1. Population: PoliceStation ({len(data['stations'])} LAPD Divisions)\n")
        f.write("INSERT INTO PoliceStation (AREA, AREA_NAME) VALUES\n")
        station_lines = [f"({area}, '{name}')" for area, name in data["stations"]]
        f.write(",\n".join(station_lines) + ";\n\n")

        # 2. CaseStatus
        f.write(f"-- 2. Population: CaseStatus ({len(data['statuses'])} Status Classifications)\n")
        f.write("INSERT INTO CaseStatus (Status, Status_Desc) VALUES\n")
        status_lines = [f"('{st}', '{desc}')" for st, desc in data["statuses"]]
        f.write(",\n".join(status_lines) + ";\n\n")

        # 3. CrimeType
        f.write(f"-- 3. Population: CrimeType ({len(data['crime_types'])} Classifications)\n")
        f.write("INSERT INTO CrimeType (Crm_Cd, Crm_Cd_Desc, Part_1_2) VALUES\n")
        crime_lines = [f"({cd}, '{desc}', {part})" for cd, desc, part in data["crime_types"]]
        f.write(",\n".join(crime_lines) + ";\n\n")

        # 4. Premises
        f.write(f"-- 4. Population: Premises ({len(data['premises'])} Location Types)\n")
        f.write("INSERT INTO Premises (Premis_Cd, Premis_Desc) VALUES\n")
        prem_lines = [f"({cd}, '{desc}')" for cd, desc in data["premises"]]
        f.write(",\n".join(prem_lines) + ";\n\n")

        # 5. Weapon
        f.write(f"-- 5. Population: Weapon ({len(data['weapons'])} Types)\n")
        f.write("INSERT INTO Weapon (Weapon_Used_Cd, Weapon_Desc) VALUES\n")
        weap_lines = [f"({cd}, '{desc}')" for cd, desc in data["weapons"]]
        f.write(",\n".join(weap_lines) + ";\n\n")

        # 6. Court
        f.write(f"-- 6. Population: Court ({len(data['courts'])} Judicial Branches)\n")
        f.write("INSERT INTO Court (CourtID, CourtName, Address, Jurisdiction) VALUES\n")
        court_lines = [f"({i}, '{c[0]}', '{c[1]}', '{c[2]}')" for i, c in enumerate(data["courts"], 1)]
        f.write(",\n".join(court_lines) + ";\n\n")

        # 7. Officer
        f.write(f"-- 7. Population: Officer ({len(data['officers'])} Detectives/Officers)\n")
        f.write("INSERT INTO Officer (OfficerID, BadgeNo, Name, `Rank`, AREA) VALUES\n")
        off_lines = [f"({off[0]}, '{off[1]}', '{off[2]}', '{off[3]}', {off[4]})" for off in data["officers"]]
        f.write(",\n".join(off_lines) + ";\n\n")

        # 8. FIR (Chunked bulk insert to prevent huge single queries)
        f.write(f"-- 8. Population: FIR (Core Entity: {len(data['firs'])} LAPD Incident Records)\n")
        chunk_size = 200
        for chunk_idx in range(0, len(data["firs"]), chunk_size):
            chunk = data["firs"][chunk_idx:chunk_idx + chunk_size]
            fir_lines = []
            for fir in chunk:
                weap = str(fir[10]) if fir[10] != "NULL" else "NULL"
                prem = str(fir[9]) if fir[9] != "NULL" else "NULL"
                fir_lines.append(
                    f"('{fir[0]}', '{fir[1]}', '{fir[2]}', {fir[3]}, {fir[4]}, {fir[5]}, "
                    f"{fir[6]}, {fir[7]}, {fir[8]}, {prem}, {weap}, '{fir[11]}', {fir[12]})"
                )
            f.write("INSERT INTO FIR (DR_NO, Date_Rptd, Date_Occ, Time_Occ, LOCATION, Cross_Street, LAT, LON, AREA, Premis_Cd, Weapon_Used_Cd, Status, OfficerID) VALUES\n")
            f.write(",\n".join(fir_lines) + ";\n\n")

        # 9. FIR_CrimeType
        f.write(f"-- 9. Population: FIR_CrimeType (M:N Junction: {len(data['fir_crimes'])} Records)\n")
        for chunk_idx in range(0, len(data["fir_crimes"]), chunk_size):
            chunk = data["fir_crimes"][chunk_idx:chunk_idx + chunk_size]
            fc_lines = [f"('{dr}', {cd})" for dr, cd in chunk]
            f.write("INSERT INTO FIR_CrimeType (DR_NO, Crm_Cd) VALUES\n")
            f.write(",\n".join(fc_lines) + ";\n\n")

        # 10. Victim
        f.write(f"-- 10. Population: Victim (Core Entity: {len(data['victims'])} Demographic Records)\n")
        for chunk_idx in range(0, len(data["victims"]), chunk_size):
            chunk = data["victims"][chunk_idx:chunk_idx + chunk_size]
            vic_lines = [f"({v[0]}, {v[1]}, {v[2]}, {v[3]}, '{v[4]}')" for v in chunk]
            f.write("INSERT INTO Victim (VictimID, Vict_Age, Vict_Sex, Vict_Descent, DR_NO) VALUES\n")
            f.write(",\n".join(vic_lines) + ";\n\n")

        # 11. Accused
        f.write(f"-- 11. Population: Accused (Core Entity: {len(data['accused'])} Suspect Records)\n")
        acc_lines = [f"({a[0]}, '{a[1]}', {a[2]}, '{a[3]}', '{a[4]}', '{a[5]}', '{a[6]}')" for a in data["accused"]]
        f.write("INSERT INTO Accused (AccusedID, Name, Age, Gender, Address, ArrestDate, DR_NO) VALUES\n")
        f.write(",\n".join(acc_lines) + ";\n\n")

        # 12. CourtCase
        f.write(f"-- 12. Population: CourtCase (Core Entity: {len(data['court_cases'])} Prosecuted Cases)\n")
        cc_lines = [f"({c[0]}, '{c[1]}', '{c[2]}', {c[3]}, {c[4]}, '{c[5]}', {c[6]}, {c[7]})" for c in data["court_cases"]]
        f.write("INSERT INTO CourtCase (CaseID, CaseNo, FilingDate, Verdict, VerdictDate, DR_NO, CourtID, AccusedID) VALUES\n")
        f.write(",\n".join(cc_lines) + ";\n\n")

        f.write("SET FOREIGN_KEY_CHECKS = 1;\n\n")
        f.write("-- Verification Query\n")
        f.write("SELECT \n")
        f.write("    (SELECT COUNT(*) FROM PoliceStation) AS PoliceStations,\n")
        f.write("    (SELECT COUNT(*) FROM Officer) AS Officers,\n")
        f.write("    (SELECT COUNT(*) FROM CrimeType) AS CrimeTypes,\n")
        f.write("    (SELECT COUNT(*) FROM Premises) AS Premises,\n")
        f.write("    (SELECT COUNT(*) FROM Weapon) AS Weapons,\n")
        f.write("    (SELECT COUNT(*) FROM CaseStatus) AS CaseStatuses,\n")
        f.write("    (SELECT COUNT(*) FROM Court) AS Courts,\n")
        f.write("    (SELECT COUNT(*) FROM FIR) AS Total_FIRs,\n")
        f.write("    (SELECT COUNT(*) FROM FIR_CrimeType) AS FIR_Crime_Links,\n")
        f.write("    (SELECT COUNT(*) FROM Victim) AS Total_Victims,\n")
        f.write("    (SELECT COUNT(*) FROM Accused) AS Total_Accused,\n")
        f.write("    (SELECT COUNT(*) FROM CourtCase) AS Total_CourtCases;\n")

    print(f"\n[SUCCESS] Successfully written to {output_path}!")
    print(f"  * FIRs (incidents): {len(data['firs'])} (Faculty target >= 100)")
    print(f"  * Victims:          {len(data['victims'])} (Faculty target >= 100)")
    print(f"  * Accused suspects: {len(data['accused'])} (Faculty target >= 100)")
    print(f"  * Court cases:      {len(data['court_cases'])} (Faculty target >= 100)")
    print(f"  * FIR_CrimeType:    {len(data['fir_crimes'])} (Faculty target >= 100)")
    print(f"  * PoliceStations:   {len(data['stations'])}")
    print(f"  * CrimeTypes:       {len(data['crime_types'])}")
    print(f"  * Premises:         {len(data['premises'])}")
    print(f"  * Weapons:          {len(data['weapons'])}")
    print(f"  * Officers:         {len(data['officers'])}")
    print(f"  * Courts:           {len(data['courts'])}")

if __name__ == "__main__":
    dataset = extract_and_generate_dataset()
    write_sql_file(dataset, "data.sql")
