-- =============================================================================
-- NOVA Pharmacy Chain — PostgreSQL schema + PL/pgSQL routines
-- Ported from the original MySQL version (dbmsproject.sql).
--
-- Run order:
--   1) Create the database once, from a superuser/`postgres` session:
--        CREATE DATABASE nova;
--   2) Connect to it, then run this file:
--        \c nova
--        \i schema.sql
--
-- Conventions:
--   * snake_case identifiers (Postgres folds unquoted names to lowercase, so
--     CamelCase would force "quoting" everywhere — avoided by design).
--   * Writes (create/update/delete)  -> PROCEDURES, invoked with CALL.
--   * Reads  (the 7 reports)          -> FUNCTIONS, invoked with SELECT * FROM ...
--   * Every routine parameter is prefixed p_ so it can never collide with a
--     column name (the original MySQL code had `WHERE Name = name`, which
--     silently matched the parameter against itself and deleted/updated ALL
--     rows — that class of bug is impossible here).
-- =============================================================================

-- Idempotent re-runs: drop in reverse dependency order.
DROP TABLE IF EXISTS prescription_drug      CASCADE;
DROP TABLE IF EXISTS prescription           CASCADE;
DROP TABLE IF EXISTS contract               CASCADE;
DROP TABLE IF EXISTS sells                  CASCADE;
DROP TABLE IF EXISTS pharmacy               CASCADE;
DROP TABLE IF EXISTS drug                   CASCADE;
DROP TABLE IF EXISTS pharmaceutical_company CASCADE;
DROP TABLE IF EXISTS patient                CASCADE;
DROP TABLE IF EXISTS doctor                 CASCADE;

-- =============================================================================
-- TABLES
-- =============================================================================

CREATE TABLE doctor (
  aadhar_id        VARCHAR(12) PRIMARY KEY,
  name             VARCHAR(100) NOT NULL,
  specialty        VARCHAR(50)  NOT NULL,
  years_experience INT          NOT NULL CHECK (years_experience >= 0)
);

CREATE TABLE patient (
  aadhar_id         VARCHAR(12) PRIMARY KEY,
  name              VARCHAR(100) NOT NULL,
  address           VARCHAR(200) NOT NULL,
  age               INT          NOT NULL CHECK (age > 0 AND age < 150),
  -- "Each patient has a primary physician" -> total participation -> NOT NULL.
  -- Deleting a doctor who is someone's primary physician is blocked (RESTRICT);
  -- reassign the patient first. This also supports "every doctor has >= 1 patient".
  primary_doctor_id VARCHAR(12)  NOT NULL,
  FOREIGN KEY (primary_doctor_id) REFERENCES doctor(aadhar_id) ON DELETE RESTRICT
);

CREATE TABLE pharmaceutical_company (
  name  VARCHAR(100) PRIMARY KEY,
  phone VARCHAR(15)  NOT NULL
);

-- Drug is a weak entity of pharmaceutical_company: trade_name is unique only
-- within a company, so the PK is composite. Requirement 4: deleting a company
-- deletes its drugs -> ON DELETE CASCADE.
CREATE TABLE drug (
  trade_name   VARCHAR(100),
  formula      VARCHAR(200) NOT NULL,
  company_name VARCHAR(100),
  PRIMARY KEY (trade_name, company_name),
  FOREIGN KEY (company_name) REFERENCES pharmaceutical_company(name) ON DELETE CASCADE
);

CREATE TABLE pharmacy (
  name    VARCHAR(100) PRIMARY KEY,
  address VARCHAR(200) NOT NULL,
  phone   VARCHAR(15)  NOT NULL
);

-- sells = the pharmacy<->drug relationship, with a per-pharmacy price
-- (same drug can cost differently at different pharmacies).
-- If a drug disappears (e.g. via company cascade) or a pharmacy is removed,
-- the corresponding catalog/price rows go with it.
CREATE TABLE sells (
  pharmacy_name VARCHAR(100),
  trade_name    VARCHAR(100),
  company_name  VARCHAR(100),
  price         DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  PRIMARY KEY (pharmacy_name, trade_name, company_name),
  FOREIGN KEY (pharmacy_name) REFERENCES pharmacy(name) ON DELETE CASCADE,
  FOREIGN KEY (trade_name, company_name) REFERENCES drug(trade_name, company_name) ON DELETE CASCADE
);

-- contract history is preserved: start_date is part of the PK, so a
-- pharmacy/company pair can have successive contracts over time.
CREATE TABLE contract (
  pharmacy_name VARCHAR(100),
  company_name  VARCHAR(100),
  start_date    DATE,
  end_date      DATE  NOT NULL,
  content       TEXT  NOT NULL,
  supervisor    VARCHAR(100) NOT NULL,  -- assigned per contract; may be changed
  PRIMARY KEY (pharmacy_name, company_name, start_date),
  CHECK (end_date >= start_date),
  FOREIGN KEY (pharmacy_name) REFERENCES pharmacy(name) ON DELETE CASCADE,
  FOREIGN KEY (company_name)  REFERENCES pharmaceutical_company(name) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- Prescription (HISTORY-PRESERVING design).
--
-- Requirement 8:
--   * A prescription is one (doctor -> patient) event on a date, and may list
--     several drugs -> the "header" and the "drug lines" are separate entities.
--   * "Doctor gives max one prescription to a patient on a given date."
--
-- Design choice: rather than the spec's "keep only the latest" (unrealistic for
-- real healthcare — you must retain history for safety/legal/audit reasons), we
-- KEEP EVERY prescription. Each slip has a surrogate prescription_id, and
-- UNIQUE (patient_id, doctor_id, prescription_date) enforces the spec's
-- "max one per doctor-patient per date" while still allowing many slips over
-- time. (To collapse this back to latest-only, drop prescription_date from the
-- UNIQUE and re-add the supersede logic in add_prescription_drug.)
-- ---------------------------------------------------------------------------
CREATE TABLE prescription (
  prescription_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  patient_id        VARCHAR(12) NOT NULL,
  doctor_id         VARCHAR(12) NOT NULL,
  prescription_date DATE NOT NULL,
  UNIQUE (patient_id, doctor_id, prescription_date),  -- max one slip per doctor-patient per date
  FOREIGN KEY (patient_id) REFERENCES patient(aadhar_id) ON DELETE CASCADE,
  FOREIGN KEY (doctor_id)  REFERENCES doctor(aadhar_id)  ON DELETE CASCADE
);

CREATE TABLE prescription_drug (
  prescription_id BIGINT,
  trade_name      VARCHAR(100),
  company_name    VARCHAR(100),
  quantity        INT NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (prescription_id, trade_name, company_name),
  FOREIGN KEY (prescription_id)
      REFERENCES prescription(prescription_id) ON DELETE CASCADE,
  FOREIGN KEY (trade_name, company_name)
      REFERENCES drug(trade_name, company_name) ON DELETE CASCADE
);

-- =============================================================================
-- WRITE PROCEDURES  (CALL <name>(...))
-- =============================================================================

-- ---- doctor ----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE insert_doctor(
  p_id VARCHAR, p_name VARCHAR, p_specialty VARCHAR, p_experience INT)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO doctor(aadhar_id, name, specialty, years_experience)
  VALUES (p_id, p_name, p_specialty, p_experience);
END;
$$;

CREATE OR REPLACE PROCEDURE update_doctor(p_id VARCHAR, p_experience INT)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE doctor SET years_experience = p_experience WHERE aadhar_id = p_id;
END;
$$;

CREATE OR REPLACE PROCEDURE delete_doctor(p_id VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM doctor WHERE aadhar_id = p_id;
END;
$$;

-- ---- patient ---------------------------------------------------------------
CREATE OR REPLACE PROCEDURE insert_patient(
  p_id VARCHAR, p_name VARCHAR, p_address VARCHAR, p_age INT, p_doctor_id VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO patient(aadhar_id, name, address, age, primary_doctor_id)
  VALUES (p_id, p_name, p_address, p_age, p_doctor_id);
END;
$$;

CREATE OR REPLACE PROCEDURE update_patient_address(p_id VARCHAR, p_address VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE patient SET address = p_address WHERE aadhar_id = p_id;
END;
$$;

CREATE OR REPLACE PROCEDURE delete_patient(p_id VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM patient WHERE aadhar_id = p_id;
END;
$$;

-- ---- pharmaceutical_company ------------------------------------------------
CREATE OR REPLACE PROCEDURE insert_company(p_name VARCHAR, p_phone VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO pharmaceutical_company(name, phone) VALUES (p_name, p_phone);
END;
$$;

CREATE OR REPLACE PROCEDURE update_company_phone(p_name VARCHAR, p_phone VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE pharmaceutical_company SET phone = p_phone WHERE name = p_name;
END;
$$;

CREATE OR REPLACE PROCEDURE delete_company(p_name VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM pharmaceutical_company WHERE name = p_name;
END;
$$;

-- ---- drug ------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE insert_drug(
  p_trade_name VARCHAR, p_formula VARCHAR, p_company_name VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO drug(trade_name, formula, company_name)
  VALUES (p_trade_name, p_formula, p_company_name);
END;
$$;

CREATE OR REPLACE PROCEDURE update_drug_formula(
  p_trade_name VARCHAR, p_company_name VARCHAR, p_formula VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE drug SET formula = p_formula
  WHERE trade_name = p_trade_name AND company_name = p_company_name;
END;
$$;

CREATE OR REPLACE PROCEDURE delete_drug(p_trade_name VARCHAR, p_company_name VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM drug WHERE trade_name = p_trade_name AND company_name = p_company_name;
END;
$$;

-- ---- pharmacy --------------------------------------------------------------
CREATE OR REPLACE PROCEDURE insert_pharmacy(
  p_name VARCHAR, p_address VARCHAR, p_phone VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO pharmacy(name, address, phone) VALUES (p_name, p_address, p_phone);
END;
$$;

CREATE OR REPLACE PROCEDURE update_pharmacy_phone(p_name VARCHAR, p_phone VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE pharmacy SET phone = p_phone WHERE name = p_name;
END;
$$;

CREATE OR REPLACE PROCEDURE delete_pharmacy(p_name VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM pharmacy WHERE name = p_name;
END;
$$;

-- ---- sells -----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE insert_sells(
  p_pharmacy_name VARCHAR, p_trade_name VARCHAR, p_company_name VARCHAR, p_price DECIMAL)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO sells(pharmacy_name, trade_name, company_name, price)
  VALUES (p_pharmacy_name, p_trade_name, p_company_name, p_price);
END;
$$;

CREATE OR REPLACE PROCEDURE update_sells_price(
  p_pharmacy_name VARCHAR, p_trade_name VARCHAR, p_company_name VARCHAR, p_price DECIMAL)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE sells SET price = p_price
  WHERE pharmacy_name = p_pharmacy_name
    AND trade_name    = p_trade_name
    AND company_name  = p_company_name;
END;
$$;

CREATE OR REPLACE PROCEDURE delete_sells(
  p_pharmacy_name VARCHAR, p_trade_name VARCHAR, p_company_name VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM sells
  WHERE pharmacy_name = p_pharmacy_name
    AND trade_name    = p_trade_name
    AND company_name  = p_company_name;
END;
$$;

-- ---- contract --------------------------------------------------------------
CREATE OR REPLACE PROCEDURE insert_contract(
  p_pharmacy_name VARCHAR, p_company_name VARCHAR, p_start_date DATE,
  p_end_date DATE, p_content TEXT, p_supervisor VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO contract(pharmacy_name, company_name, start_date, end_date, content, supervisor)
  VALUES (p_pharmacy_name, p_company_name, p_start_date, p_end_date, p_content, p_supervisor);
END;
$$;

CREATE OR REPLACE PROCEDURE update_contract_supervisor(
  p_pharmacy_name VARCHAR, p_company_name VARCHAR, p_start_date DATE, p_supervisor VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE contract SET supervisor = p_supervisor
  WHERE pharmacy_name = p_pharmacy_name
    AND company_name  = p_company_name
    AND start_date    = p_start_date;
END;
$$;

CREATE OR REPLACE PROCEDURE delete_contract(
  p_pharmacy_name VARCHAR, p_company_name VARCHAR, p_start_date DATE)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM contract
  WHERE pharmacy_name = p_pharmacy_name
    AND company_name  = p_company_name
    AND start_date    = p_start_date;
END;
$$;

-- ---- prescription ----------------------------------------------------------
-- Adds one drug line to a (doctor -> patient -> date) slip. History-preserving:
-- every dated slip is kept; the slip for a given date is created on first use
-- and reused for subsequent drug lines on that same date.
--   * no slip yet for that date -> create the header, add the line
--   * slip exists for that date -> reuse it, add/replace this drug line
CREATE OR REPLACE PROCEDURE add_prescription_drug(
  p_patient_id VARCHAR, p_doctor_id VARCHAR, p_date DATE,
  p_trade_name VARCHAR, p_company_name VARCHAR, p_quantity INT)
LANGUAGE plpgsql AS $$
DECLARE
  v_id BIGINT;
BEGIN
  -- find this doctor's slip for this patient ON THIS DATE (older slips are kept)
  SELECT prescription_id INTO v_id
  FROM prescription
  WHERE patient_id = p_patient_id
    AND doctor_id  = p_doctor_id
    AND prescription_date = p_date;

  IF NOT FOUND THEN
    INSERT INTO prescription(patient_id, doctor_id, prescription_date)
    VALUES (p_patient_id, p_doctor_id, p_date)
    RETURNING prescription_id INTO v_id;
  END IF;

  INSERT INTO prescription_drug(prescription_id, trade_name, company_name, quantity)
  VALUES (v_id, p_trade_name, p_company_name, p_quantity)
  ON CONFLICT (prescription_id, trade_name, company_name)
  DO UPDATE SET quantity = EXCLUDED.quantity;
END;
$$;

CREATE OR REPLACE PROCEDURE update_prescription_qty(
  p_prescription_id BIGINT, p_trade_name VARCHAR, p_company_name VARCHAR, p_quantity INT)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE prescription_drug SET quantity = p_quantity
  WHERE prescription_id = p_prescription_id
    AND trade_name      = p_trade_name
    AND company_name    = p_company_name;
END;
$$;

-- Remove a single drug line from a prescription.
CREATE OR REPLACE PROCEDURE delete_prescription_drug(
  p_prescription_id BIGINT, p_trade_name VARCHAR, p_company_name VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM prescription_drug
  WHERE prescription_id = p_prescription_id
    AND trade_name      = p_trade_name
    AND company_name    = p_company_name;
END;
$$;

-- Remove an entire prescription (its drug lines cascade away).
CREATE OR REPLACE PROCEDURE delete_prescription(p_prescription_id BIGINT)
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM prescription WHERE prescription_id = p_prescription_id;
END;
$$;

-- =============================================================================
-- REPORT FUNCTIONS  (SELECT * FROM <name>(...))
-- =============================================================================

-- 2. Prescriptions of a patient within a period.
CREATE OR REPLACE FUNCTION get_prescriptions_in_period(
  p_patient_id VARCHAR, p_from DATE, p_to DATE)
RETURNS TABLE(prescription_id BIGINT, doctor_id VARCHAR, prescription_date DATE,
              trade_name VARCHAR, company_name VARCHAR, quantity INT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
    SELECT p.prescription_id, p.doctor_id, p.prescription_date,
           pd.trade_name, pd.company_name, pd.quantity
    FROM prescription p
    JOIN prescription_drug pd ON pd.prescription_id = p.prescription_id
    WHERE p.patient_id = p_patient_id
      AND p.prescription_date BETWEEN p_from AND p_to
    ORDER BY p.prescription_date;
END;
$$;

-- 3. Details of a patient's prescription on a specific date.
CREATE OR REPLACE FUNCTION get_prescription_by_date(p_patient_id VARCHAR, p_date DATE)
RETURNS TABLE(prescription_id BIGINT, doctor_id VARCHAR,
              trade_name VARCHAR, company_name VARCHAR, quantity INT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
    SELECT p.prescription_id, p.doctor_id, pd.trade_name, pd.company_name, pd.quantity
    FROM prescription p
    JOIN prescription_drug pd ON pd.prescription_id = p.prescription_id
    WHERE p.patient_id = p_patient_id AND p.prescription_date = p_date;
END;
$$;

-- 4. Drugs produced by a pharmaceutical company.
CREATE OR REPLACE FUNCTION get_drugs_by_company(p_company_name VARCHAR)
RETURNS TABLE(trade_name VARCHAR, formula VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
    SELECT d.trade_name, d.formula FROM drug d WHERE d.company_name = p_company_name;
END;
$$;

-- 5. Stock position of a pharmacy.
--    NOTE: the spec stores only a per-drug price (no on-hand quantity), so
--    "stock position" here = the drug catalog the pharmacy sells + its prices.
--    If an inventory count were required, add sells.stock_qty and return it.
CREATE OR REPLACE FUNCTION get_pharmacy_stock(p_pharmacy_name VARCHAR)
RETURNS TABLE(trade_name VARCHAR, company_name VARCHAR, price DECIMAL)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
    SELECT s.trade_name, s.company_name, s.price
    FROM sells s WHERE s.pharmacy_name = p_pharmacy_name;
END;
$$;

-- 6. Contact details of the companies a pharmacy has contracts with.
CREATE OR REPLACE FUNCTION get_pharmacy_company_contact(p_pharmacy_name VARCHAR)
RETURNS TABLE(company_name VARCHAR, phone VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
    SELECT DISTINCT pc.name, pc.phone
    FROM contract c
    JOIN pharmaceutical_company pc ON pc.name = c.company_name
    WHERE c.pharmacy_name = p_pharmacy_name;
END;
$$;

-- 7. Patients for a given doctor (their primary physician).
CREATE OR REPLACE FUNCTION get_patients_by_doctor(p_doctor_id VARCHAR)
RETURNS TABLE(aadhar_id VARCHAR, name VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
    SELECT pt.aadhar_id, pt.name FROM patient pt WHERE pt.primary_doctor_id = p_doctor_id;
END;
$$;

-- =============================================================================
-- Constraints that CANNOT be expressed in DDL (documented, enforce in app/trigger):
--   * "Every doctor has at least one patient"  — participation constraint;
--     would need a deferred constraint trigger.
--   * "Each pharmacy sells at least 10 drugs"  — cardinality floor; likewise a
--     trigger or an application-level check.
-- =============================================================================
