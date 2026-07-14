-- =============================================================================
-- NOVA — seed / dummy data
-- Run AFTER postgres_schema.sql, connected to the nova database:
--     \c nova
--     \i seed.sql
--
-- Re-runnable: TRUNCATE ... RESTART IDENTITY resets rows AND the drug_id /
-- prescription_id sequences, so ids start from 1 each time (predictable demos).
-- Drug lines / sells reference drugs by their (trade_name, company_name) natural
-- key via a JOIN, so the seed never hard-codes surrogate ids.
-- =============================================================================

TRUNCATE prescription_drug, prescription, contract, sells,
         drug, pharmacy, pharmaceutical_company, patient, doctor
         RESTART IDENTITY CASCADE;

-- ---- doctors ---------------------------------------------------------------
INSERT INTO doctor(aadhar_id, name, specialty, years_experience) VALUES
  ('100000000001', 'Dr. Anil Kumar',    'Cardiology',        15),
  ('100000000002', 'Dr. Meera Nair',    'Pediatrics',         8),
  ('100000000003', 'Dr. Rakesh Sharma', 'Orthopedics',       20),
  ('100000000004', 'Dr. Sunita Rao',    'Dermatology',        5),
  ('100000000005', 'Dr. Vikram Singh',  'General Medicine',  12);

-- ---- patients (every doctor gets >= 1 patient -> participation constraint) --
INSERT INTO patient(aadhar_id, name, address, age, primary_doctor_id) VALUES
  ('200000000001', 'Asha Verma',   'Andheri, Mumbai',       34, '100000000001'),
  ('200000000002', 'Rohan Mehta',  'Kothrud, Pune',         45, '100000000001'),
  ('200000000003', 'Priya Iyer',   'Indiranagar, Bangalore',29, '100000000002'),
  ('200000000004', 'Karan Gupta',  'Rohini, Delhi',          7, '100000000002'),
  ('200000000005', 'Neha Joshi',   'Dadar, Mumbai',         52, '100000000003'),
  ('200000000006', 'Amit Patel',   'Navrangpura, Ahmedabad',61, '100000000003'),
  ('200000000007', 'Sneha Reddy',  'Gachibowli, Hyderabad', 25, '100000000004'),
  ('200000000008', 'Manoj Desai',  'Adajan, Surat',         40, '100000000005');

-- ---- pharmaceutical companies ----------------------------------------------
INSERT INTO pharmaceutical_company(name, phone) VALUES
  ('GSK',        '022-40001111'),
  ('Cipla',      '022-40002222'),
  ('Sun Pharma', '022-40003333'),
  ('Dr Reddys',  '040-40004444');

-- ---- drugs (trade_name unique within a company; drug_id auto) --------------
INSERT INTO drug(trade_name, company_name, formula) VALUES
  ('Crocin',    'GSK',        'Paracetamol 500mg'),
  ('Augmentin', 'GSK',        'Amoxicillin + Clavulanate 625mg'),
  ('Ventorlin', 'GSK',        'Salbutamol 2mg'),
  ('Zinetac',   'GSK',        'Ranitidine 150mg'),
  ('Azee',      'Cipla',      'Azithromycin 500mg'),
  ('Asthalin',  'Cipla',      'Salbutamol 4mg'),
  ('Okacet',    'Cipla',      'Cetirizine 10mg'),
  ('Montair',   'Cipla',      'Montelukast 10mg'),
  ('Volini',    'Sun Pharma', 'Diclofenac Gel 1%'),
  ('Pantocid',  'Sun Pharma', 'Pantoprazole 40mg'),
  ('Rosuvas',   'Sun Pharma', 'Rosuvastatin 10mg'),
  ('Gluconorm', 'Sun Pharma', 'Metformin 500mg'),
  ('Omez',      'Dr Reddys',  'Omeprazole 20mg'),
  ('Nise',      'Dr Reddys',  'Nimesulide 100mg'),
  ('Stamlo',    'Dr Reddys',  'Amlodipine 5mg'),
  ('Econorm',   'Dr Reddys',  'Saccharomyces boulardii');

-- ---- pharmacies ------------------------------------------------------------
INSERT INTO pharmacy(name, address, phone) VALUES
  ('MedPlus Andheri',    'Andheri West, Mumbai',    '022-26001234'),
  ('Apollo Koramangala', 'Koramangala, Bangalore',  '080-25005678'),
  ('Wellness Baner',     'Baner, Pune',             '020-27009012');

-- ---- sells (each pharmacy sells >= 10 drugs; same drug priced differently) --
-- drug_id is looked up by joining the (trade_name, company_name) natural key.
INSERT INTO sells(pharmacy_name, drug_id, price)
SELECT 'MedPlus Andheri', d.drug_id, v.price
FROM (VALUES
  ('Crocin','GSK', 28.00), ('Augmentin','GSK',132.00), ('Ventorlin','GSK',18.00),
  ('Zinetac','GSK',12.00), ('Azee','Cipla',110.00),    ('Asthalin','Cipla',22.00),
  ('Okacet','Cipla',15.00),('Montair','Cipla',95.00),  ('Volini','Sun Pharma',145.00),
  ('Pantocid','Sun Pharma',88.00), ('Omez','Dr Reddys',45.00), ('Nise','Dr Reddys',32.00)
) AS v(tn, cn, price)
JOIN drug d ON d.trade_name = v.tn AND d.company_name = v.cn;

INSERT INTO sells(pharmacy_name, drug_id, price)
SELECT 'Apollo Koramangala', d.drug_id, v.price
FROM (VALUES
  ('Crocin','GSK', 30.00), ('Augmentin','GSK',138.00), ('Azee','Cipla',115.00),
  ('Okacet','Cipla',16.50),('Montair','Cipla',99.00),  ('Volini','Sun Pharma',150.00),
  ('Pantocid','Sun Pharma',92.00),('Rosuvas','Sun Pharma',165.00),('Gluconorm','Sun Pharma',24.00),
  ('Omez','Dr Reddys',47.00), ('Stamlo','Dr Reddys',38.00), ('Econorm','Dr Reddys',78.00)
) AS v(tn, cn, price)
JOIN drug d ON d.trade_name = v.tn AND d.company_name = v.cn;

INSERT INTO sells(pharmacy_name, drug_id, price)
SELECT 'Wellness Baner', d.drug_id, v.price
FROM (VALUES
  ('Crocin','GSK', 26.50), ('Ventorlin','GSK',17.00), ('Zinetac','GSK',11.50),
  ('Asthalin','Cipla',21.00),('Okacet','Cipla',14.00),('Volini','Sun Pharma',140.00),
  ('Rosuvas','Sun Pharma',158.00),('Gluconorm','Sun Pharma',23.00),('Omez','Dr Reddys',43.00),
  ('Nise','Dr Reddys',30.00), ('Stamlo','Dr Reddys',36.50), ('Econorm','Dr Reddys',75.00)
) AS v(tn, cn, price)
JOIN drug d ON d.trade_name = v.tn AND d.company_name = v.cn;

-- ---- contracts (pharmacy <-> company, with supervisor) ---------------------
INSERT INTO contract(pharmacy_name, company_name, start_date, end_date, content, supervisor) VALUES
  ('MedPlus Andheri',    'GSK',        '2024-01-01', '2025-12-31', 'Supply of GSK products at agreed slab rates.',   'Ramesh Kulkarni'),
  ('MedPlus Andheri',    'Cipla',      '2024-03-15', '2026-03-14', 'Cipla product distribution agreement.',          'Ramesh Kulkarni'),
  ('Apollo Koramangala', 'Sun Pharma', '2024-06-01', '2025-05-31', 'Sun Pharma supply contract, quarterly review.',  'Latha Menon'),
  ('Apollo Koramangala', 'GSK',        '2024-02-01', '2025-01-31', 'GSK supply for Bangalore region.',               'Latha Menon'),
  ('Wellness Baner',     'Dr Reddys',  '2025-01-01', '2026-12-31', 'Dr Reddys annual distribution contract.',        'Sachin Pawar');

-- ---- prescriptions ---------------------------------------------------------
-- Headers first (one per doctor -> patient -> date). Note Asha (…001) has TWO
-- slips from Dr. Anil on different dates -> history is preserved -> report #2
-- returns both. Asha also gets a slip from Dr. Meera -> a patient sees several
-- doctors.
INSERT INTO prescription(patient_id, doctor_id, prescription_date) VALUES
  ('200000000001', '100000000001', '2025-06-10'),
  ('200000000001', '100000000001', '2025-07-01'),
  ('200000000001', '100000000002', '2025-06-15'),
  ('200000000003', '100000000002', '2025-06-20'),
  ('200000000005', '100000000003', '2025-05-05'),
  ('200000000006', '100000000003', '2026-01-10'),
  ('200000000007', '100000000004', '2025-12-01'),
  ('200000000008', '100000000005', '2026-02-20');

-- Drug lines: joined to the header by (patient, doctor, date) and to the drug
-- by (trade_name, company_name), so no surrogate ids are hard-coded.
INSERT INTO prescription_drug(prescription_id, drug_id, quantity)
SELECT p.prescription_id, d.drug_id, v.qty
FROM (VALUES
  ('200000000001','100000000001', DATE '2025-06-10', 'Crocin',    'GSK',        15),
  ('200000000001','100000000001', DATE '2025-06-10', 'Augmentin', 'GSK',        10),
  ('200000000001','100000000001', DATE '2025-07-01', 'Azee',      'Cipla',       5),
  ('200000000001','100000000002', DATE '2025-06-15', 'Okacet',    'Cipla',      20),
  ('200000000003','100000000002', DATE '2025-06-20', 'Montair',   'Cipla',      30),
  ('200000000003','100000000002', DATE '2025-06-20', 'Asthalin',  'Cipla',      10),
  ('200000000005','100000000003', DATE '2025-05-05', 'Volini',    'Sun Pharma', 12),
  ('200000000005','100000000003', DATE '2025-05-05', 'Pantocid',  'Sun Pharma', 14),
  ('200000000006','100000000003', DATE '2026-01-10', 'Rosuvas',   'Sun Pharma', 30),
  ('200000000006','100000000003', DATE '2026-01-10', 'Gluconorm', 'Sun Pharma', 60),
  ('200000000007','100000000004', DATE '2025-12-01', 'Nise',      'Dr Reddys',  10),
  ('200000000008','100000000005', DATE '2026-02-20', 'Omez',      'Dr Reddys',  14)
) AS v(pid, did, pdate, tn, cn, qty)
JOIN prescription p
  ON p.patient_id = v.pid AND p.doctor_id = v.did AND p.prescription_date = v.pdate
JOIN drug d
  ON d.trade_name = v.tn AND d.company_name = v.cn;
