-- Use the correct database
CREATE DATABASE IF NOT EXISTS nova;
USE nova;

-- Create tables
CREATE TABLE Doctor (
  AadharID VARCHAR(12) PRIMARY KEY,
  Name VARCHAR(100),
  Specialty VARCHAR(50),
  YearsExperience INT
);

CREATE TABLE Patient (
  AadharID VARCHAR(12) PRIMARY KEY,
  Name VARCHAR(100),
  Address VARCHAR(200),
  Age INT,
  PrimaryDoctorID VARCHAR(12),
  FOREIGN KEY (PrimaryDoctorID) REFERENCES Doctor(AadharID)
);

CREATE TABLE PharmaceuticalCompany (
  Name VARCHAR(100) PRIMARY KEY,
  Phone VARCHAR(15)
);

CREATE TABLE Drug (
  TradeName VARCHAR(100),
  Formula VARCHAR(200),
  CompanyName VARCHAR(100),
  PRIMARY KEY (TradeName, CompanyName),
  FOREIGN KEY (CompanyName) REFERENCES PharmaceuticalCompany(Name) ON DELETE CASCADE
);

CREATE TABLE Pharmacy (
  Name VARCHAR(100) PRIMARY KEY,
  Address VARCHAR(200),
  Phone VARCHAR(15)
);

CREATE TABLE Sells (
  PharmacyName VARCHAR(100),
  TradeName VARCHAR(100),
  CompanyName VARCHAR(100),
  Price DECIMAL(10,2),
  PRIMARY KEY (PharmacyName, TradeName, CompanyName),
  FOREIGN KEY (PharmacyName) REFERENCES Pharmacy(Name),
  FOREIGN KEY (TradeName, CompanyName) REFERENCES Drug(TradeName, CompanyName)
);

CREATE TABLE Contract (
  PharmacyName VARCHAR(100),
  CompanyName VARCHAR(100),
  StartDate DATE,
  EndDate DATE,
  Content TEXT,
  Supervisor VARCHAR(100),
  PRIMARY KEY (PharmacyName, CompanyName, StartDate),
  FOREIGN KEY (PharmacyName) REFERENCES Pharmacy(Name),
  FOREIGN KEY (CompanyName) REFERENCES PharmaceuticalCompany(Name)
);

CREATE TABLE Prescription (
  PatientID VARCHAR(12),
  DoctorID VARCHAR(12),
  PrescriptionDate DATE,
  TradeName VARCHAR(100),
  CompanyName VARCHAR(100),
  Quantity INT,
  PRIMARY KEY (PatientID, DoctorID, PrescriptionDate, TradeName, CompanyName),
  FOREIGN KEY (PatientID) REFERENCES Patient(AadharID),
  FOREIGN KEY (DoctorID) REFERENCES Doctor(AadharID),
  FOREIGN KEY (TradeName, CompanyName) REFERENCES Drug(TradeName, CompanyName)
);


-- Doctor
CREATE PROCEDURE InsertDoctor (IN id VARCHAR(12), IN name VARCHAR(100), IN specialty VARCHAR(50), IN exp INT)
BEGIN
  INSERT INTO Doctor VALUES (id, name, specialty, exp);
END;//

CREATE PROCEDURE UpdateDoctor (IN id VARCHAR(12), IN exp INT)
BEGIN
  UPDATE Doctor SET YearsExperience = exp WHERE AadharID = id;
END;//

CREATE PROCEDURE DeleteDoctor (IN id VARCHAR(12))
BEGIN
  DELETE FROM Doctor WHERE AadharID = id;
END;//

-- Patient
CREATE PROCEDURE InsertPatient (IN id VARCHAR(12), IN name VARCHAR(100), IN addr VARCHAR(200), IN age INT, IN docid VARCHAR(12))
BEGIN
  INSERT INTO Patient VALUES (id, name, addr, age, docid);
END;//

CREATE PROCEDURE UpdatePatientAddress (IN id VARCHAR(12), IN addr VARCHAR(200))
BEGIN
  UPDATE Patient SET Address = addr WHERE AadharID = id;
END;//

CREATE PROCEDURE DeletePatient (IN id VARCHAR(12))
BEGIN
  DELETE FROM Patient WHERE AadharID = id;
END;//

-- Pharmaceutical Company
CREATE PROCEDURE InsertCompany (IN name VARCHAR(100), IN phone VARCHAR(15))
BEGIN
  INSERT INTO PharmaceuticalCompany VALUES (name, phone);
END;//

CREATE PROCEDURE UpdateCompanyPhone (IN name VARCHAR(100), IN phone VARCHAR(15))
BEGIN
  UPDATE PharmaceuticalCompany SET Phone = phone WHERE Name = name;
END;//

CREATE PROCEDURE DeleteCompany (IN name VARCHAR(100))
BEGIN
  DELETE FROM PharmaceuticalCompany WHERE Name = name;
END;//

-- Drug
CREATE PROCEDURE InsertDrug (IN name VARCHAR(100), IN formula VARCHAR(200), IN company VARCHAR(100))
BEGIN
  INSERT INTO Drug VALUES (name, formula, company);
END;//

CREATE PROCEDURE UpdateDrugFormula (IN name VARCHAR(100), IN company VARCHAR(100), IN formula VARCHAR(200))
BEGIN
  UPDATE Drug SET Formula = formula WHERE TradeName = name AND CompanyName = company;
END;//

CREATE PROCEDURE DeleteDrug (IN name VARCHAR(100), IN company VARCHAR(100))
BEGIN
  DELETE FROM Drug WHERE TradeName = name AND CompanyName = company;
END;//

-- Pharmacy
CREATE PROCEDURE InsertPharmacy (IN name VARCHAR(100), IN addr VARCHAR(200), IN phone VARCHAR(15))
BEGIN
  INSERT INTO Pharmacy VALUES (name, addr, phone);
END;//

CREATE PROCEDURE UpdatePharmacyPhone (IN name VARCHAR(100), IN phone VARCHAR(15))
BEGIN
  UPDATE Pharmacy SET Phone = phone WHERE Name = name;
END;//

CREATE PROCEDURE DeletePharmacy (IN name VARCHAR(100))
BEGIN
  DELETE FROM Pharmacy WHERE Name = name;
END;//

-- Sells
CREATE PROCEDURE InsertSells (IN pname VARCHAR(100), IN dname VARCHAR(100), IN cname VARCHAR(100), IN price DECIMAL(10,2))
BEGIN
  INSERT INTO Sells VALUES (pname, dname, cname, price);
END;//

CREATE PROCEDURE UpdateSellsPrice (IN pname VARCHAR(100), IN dname VARCHAR(100), IN cname VARCHAR(100), IN price DECIMAL(10,2))
BEGIN
  UPDATE Sells SET Price = price WHERE PharmacyName = pname AND TradeName = dname AND CompanyName = cname;
END;//

CREATE PROCEDURE DeleteSells (IN pname VARCHAR(100), IN dname VARCHAR(100), IN cname VARCHAR(100))
BEGIN
  DELETE FROM Sells WHERE PharmacyName = pname AND TradeName = dname AND CompanyName = cname;
END;//

-- Contract
CREATE PROCEDURE InsertContract (IN pname VARCHAR(100), IN cname VARCHAR(100), IN sdate DATE, IN edate DATE, IN content TEXT, IN supervisor VARCHAR(100))
BEGIN
  INSERT INTO Contract VALUES (pname, cname, sdate, edate, content, supervisor);
END;//

CREATE PROCEDURE UpdateContractSupervisor (IN pname VARCHAR(100), IN cname VARCHAR(100), IN sdate DATE, IN supervisor VARCHAR(100))
BEGIN
  UPDATE Contract SET Supervisor = supervisor WHERE PharmacyName = pname AND CompanyName = cname AND StartDate = sdate;
END;//

CREATE PROCEDURE DeleteContract (IN pname VARCHAR(100), IN cname VARCHAR(100), IN sdate DATE)
BEGIN
  DELETE FROM Contract WHERE PharmacyName = pname AND CompanyName = cname AND StartDate = sdate;
END;//

-- Prescription
CREATE PROCEDURE InsertPrescription (IN pid VARCHAR(12), IN did VARCHAR(12), IN pdate DATE, IN dname VARCHAR(100), IN cname VARCHAR(100), IN qty INT)
BEGIN
  INSERT INTO Prescription VALUES (pid, did, pdate, dname, cname, qty);
END;//

CREATE PROCEDURE UpdatePrescriptionQty (IN pid VARCHAR(12), IN did VARCHAR(12), IN pdate DATE, IN dname VARCHAR(100), IN cname VARCHAR(100), IN qty INT)
BEGIN
  UPDATE Prescription SET Quantity = qty WHERE PatientID = pid AND DoctorID = did AND PrescriptionDate = pdate AND TradeName = dname AND CompanyName = cname;
END;//

CREATE PROCEDURE DeletePrescription (IN pid VARCHAR(12), IN did VARCHAR(12), IN pdate DATE, IN dname VARCHAR(100), IN cname VARCHAR(100))
BEGIN
  DELETE FROM Prescription WHERE PatientID = pid AND DoctorID = did AND PrescriptionDate = pdate AND TradeName = dname AND CompanyName = cname;
END;//



-- 2. Report on prescriptions for a patient in a given period
CREATE PROCEDURE GetPrescriptionsInPeriod (
  IN patientId VARCHAR(12), IN fromDate DATE, IN toDate DATE
)
BEGIN
  SELECT * FROM Prescription
  WHERE PatientID = patientId AND PrescriptionDate BETWEEN fromDate AND toDate;
END;//

-- 3. Details of a prescription for a patient on a specific date
CREATE PROCEDURE GetPrescriptionByDate (
  IN patientId VARCHAR(12), IN prescDate DATE
)
BEGIN
  SELECT * FROM Prescription
  WHERE PatientID = patientId AND PrescriptionDate = prescDate;
END;//

-- 4. Drugs produced by a pharmaceutical company
CREATE PROCEDURE GetDrugsByCompany (
  IN companyName VARCHAR(100)
)
BEGIN
  SELECT * FROM Drug WHERE CompanyName = companyName;
END;//

-- 5. Stock position of a pharmacy
CREATE PROCEDURE GetPharmacyStock (
  IN pharmacyName VARCHAR(100)
)
BEGIN
  SELECT TradeName, CompanyName, Price
  FROM Sells WHERE PharmacyName = pharmacyName;
END;//

-- 6. Contact details of a pharmacy-pharmaceutical company
CREATE PROCEDURE GetPharmacyCompanyContact (
  IN pharmacyName VARCHAR(100)
)
BEGIN
  SELECT c.CompanyName, pc.Phone
  FROM Contract c
  JOIN PharmaceuticalCompany pc ON c.CompanyName = pc.Name
  WHERE c.PharmacyName = pharmacyName;
END;//

-- 7. List of patients for a given doctor
CREATE PROCEDURE GetPatientsByDoctor (
  IN doctorId VARCHAR(12)
)
BEGIN
  SELECT AadharID, Name FROM Patient WHERE PrimaryDoctorID = doctorId;
END;//

DELIMITER ;
