-- Creating tables based on the relational schema

-- PHARMACEUTICAL_COMPANY table
CREATE TABLE PHARMACEUTICAL_COMPANY (
    CName VARCHAR(100) PRIMARY KEY,
    CPhone VARCHAR(15) NOT NULL
);

-- PHARMACY table
CREATE TABLE PHARMACY (
    PName VARCHAR(100) PRIMARY KEY,
    PAddress VARCHAR(200) NOT NULL,
    PPhone VARCHAR(15) NOT NULL
);

-- DOCTOR table
CREATE TABLE DOCTOR (
    AadharID VARCHAR(12) PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Speciality VARCHAR(100) NOT NULL, -- may be NULL
    Yrs_Experience NUMBER NOT NULL
);

-- PATIENT table
CREATE TABLE PATIENT (
    AadharID VARCHAR(12) PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Age NUMBER NOT NULL,
    Address VARCHAR(200) NOT NULL,
    PhysicianID VARCHAR(12) NOT NULL,
    FOREIGN KEY (PhysicianID) REFERENCES DOCTOR(AadharID) ON DELETE CASCADE
);

-- TREATED_BY table (doctor-patient relationship)
CREATE TABLE TREATED_BY (
    DoctorID VARCHAR(12),
    PatientID VARCHAR(12),
    PRIMARY KEY (DoctorID, PatientID),
    FOREIGN KEY (DoctorID) REFERENCES DOCTOR(AadharID) ON DELETE CASCADE,
    FOREIGN KEY (PatientID) REFERENCES PATIENT(AadharID) ON DELETE CASCADE
);

-- DRUG table
CREATE TABLE DRUG (
    CName VARCHAR(100),
    Trade_Name VARCHAR(100),
    Formula VARCHAR(200) NOT NULL,
    PRIMARY KEY (CName, Trade_Name),
    FOREIGN KEY (CName) REFERENCES PHARMACEUTICAL_COMPANY(CName) ON DELETE CASCADE    
);

-- SELLS table (pharmacy-drug relationship with price)
CREATE TABLE SELLS (
    PName VARCHAR(100),
    CName VARCHAR(100),
    Drug VARCHAR(100),
    Price NUMBER(10,2) NOT NULL,
    PRIMARY KEY (PName, CName, Drug),
    FOREIGN KEY (PName) REFERENCES PHARMACY(PName) ON DELETE CASCADE,
    FOREIGN KEY (CName, Drug) REFERENCES DRUG(CName, Trade_Name) ON DELETE CASCADE
);

-- CONTRACTS table
CREATE TABLE CONTRACTS (
    PName VARCHAR(100),
    CName VARCHAR(100),
    Start_Date DATE NOT NULL,
    End_Date DATE NOT NULL,
    Supervisor VARCHAR(100) NOT NULL,
    Content CLOB,
    PRIMARY KEY (PName, CName,Start_Date,End_Date),
    FOREIGN KEY (PName) REFERENCES PHARMACY(PName) ON DELETE CASCADE,
    FOREIGN KEY (CName) REFERENCES PHARMACEUTICAL_COMPANY(CName) ON DELETE CASCADE,
    CHECK (End_Date > Start_Date)
);

-- PRESCRIPTION table
CREATE TABLE PRESCRIPTION (
    PrescID VARCHAR(20) NOT NULL,
    DoctorID VARCHAR(12) NOT NULL,
    PatientID VARCHAR(12) NOT NULL,
    PDate DATE NOT NULL,
    --PDate
    PRIMARY KEY (DoctorID,PatientID,PDate),
    FOREIGN KEY (DoctorID) REFERENCES DOCTOR(AadharID) ON DELETE CASCADE,
    FOREIGN KEY (PatientID) REFERENCES PATIENT(AadharID) ON DELETE CASCADE,
    CONSTRAINT unique_presc_ID UNIQUE (PrescID)
);

-- PRESC_DETAILS table (details of drugs in prescriptions)
CREATE TABLE PRESC_DETAILS (
    PrescID VARCHAR(20),
    CName VARCHAR(100),
    Drug VARCHAR(100),
    Quantity NUMBER NOT NULL,
    PRIMARY KEY (PrescID, CName, Drug),
    FOREIGN KEY (PrescID) REFERENCES PRESCRIPTION(PrescID) ON DELETE CASCADE,
    FOREIGN KEY (CName, Drug) REFERENCES DRUG(CName, Trade_Name)
);
--Done till here 1

--Triggers to take care of ON UPDATE CASCADE OF FK's
-- 1. When DOCTOR.AadharID changes, cascade to PATIENT, TREATED_BY and PRESCRIPTION
CREATE OR REPLACE TRIGGER trg_doctor_aadharid_update
AFTER UPDATE OF AadharID ON DOCTOR
FOR EACH ROW
BEGIN
  -- PATIENT.PhysicianID → DOCTOR.AadharID
  UPDATE PATIENT
    SET PhysicianID = :NEW.AadharID
    WHERE PhysicianID = :OLD.AadharID;
  -- TREATED_BY.DoctorID → DOCTOR.AadharID
  UPDATE TREATED_BY
    SET DoctorID = :NEW.AadharID
    WHERE DoctorID = :OLD.AadharID;
  -- PRESCRIPTION.DoctorID → DOCTOR.AadharID
  UPDATE PRESCRIPTION
    SET DoctorID = :NEW.AadharID
    WHERE DoctorID = :OLD.AadharID;
END;
/

-- 2. When PATIENT.AadharID changes, cascade to TREATED_BY and PRESCRIPTION
CREATE OR REPLACE TRIGGER trg_patient_aadharid_update
AFTER UPDATE OF AadharID ON PATIENT
FOR EACH ROW
BEGIN
  -- TREATED_BY.PatientID → PATIENT.AadharID
  UPDATE TREATED_BY
    SET PatientID = :NEW.AadharID
    WHERE PatientID = :OLD.AadharID;
  -- PRESCRIPTION.PatientID → PATIENT.AadharID
  UPDATE PRESCRIPTION
    SET PatientID = :NEW.AadharID
    WHERE PatientID = :OLD.AadharID;
END;
/

-- 3. When PHARMACEUTICAL_COMPANY.CName changes, cascade to DRUG, SELLS and CONTRACTS
CREATE OR REPLACE TRIGGER trg_pharmco_cname_update
AFTER UPDATE OF CName ON PHARMACEUTICAL_COMPANY
FOR EACH ROW
BEGIN
  -- DRUG.CName → PHARMACEUTICAL_COMPANY.CName
  UPDATE DRUG
    SET CName = :NEW.CName
    WHERE CName = :OLD.CName;
  -- SELLS.CName → PHARMACEUTICAL_COMPANY.CName
  UPDATE SELLS
    SET CName = :NEW.CName
    WHERE CName = :OLD.CName;
  -- CONTRACTS.CName → PHARMACEUTICAL_COMPANY.CName
  UPDATE CONTRACTS
    SET CName = :NEW.CName
    WHERE CName = :OLD.CName;
END;
/

-- 4. When PHARMACY.PName changes, cascade to SELLS and CONTRACTS
CREATE OR REPLACE TRIGGER trg_pharmacy_pname_update
AFTER UPDATE OF PName ON PHARMACY
FOR EACH ROW
BEGIN
  -- SELLS.PName → PHARMACY.PName
  UPDATE SELLS
    SET PName = :NEW.PName
    WHERE PName = :OLD.PName;
  -- CONTRACTS.PName → PHARMACY.PName
  UPDATE CONTRACTS
    SET PName = :NEW.PName
    WHERE PName = :OLD.PName;
END;
/

-- 5. When DRUG primary key (CName, Trade_Name) changes, cascade to SELLS
CREATE OR REPLACE TRIGGER trg_drug_pk_update
AFTER UPDATE OF CName, Trade_Name ON DRUG
FOR EACH ROW
BEGIN
  -- Cascade into SELLS
  UPDATE SELLS
     SET CName = :NEW.CName,
         Drug  = :NEW.Trade_Name
   WHERE CName = :OLD.CName
     AND Drug  = :OLD.Trade_Name;

  -- Cascade into PRESC_DETAILS
  UPDATE PRESC_DETAILS
     SET CName = :NEW.CName,
         Drug  = :NEW.Trade_Name
   WHERE CName = :OLD.CName
     AND Drug  = :OLD.Trade_Name;
END;
/


-- 6. When PRESCRIPTION.PrescID changes, cascade to PRESC_DETAILS
CREATE OR REPLACE TRIGGER trg_prescription_presc_id_update
AFTER UPDATE OF PrescID ON PRESCRIPTION
FOR EACH ROW
BEGIN
  UPDATE PRESC_DETAILS
    SET PrescID = :NEW.PrescID
    WHERE PrescID = :OLD.PrescID;
END;
/


-- Triggers to enforce constraints
-- Trigger for latest date saving of a doctor-patient combination
CREATE OR REPLACE TRIGGER latest_date_const
BEFORE INSERT OR UPDATE ON PRESCRIPTION
FOR EACH ROW
DECLARE
    v_old_presc_id PRESCRIPTION.PrescID%TYPE;
    v_count NUMBER;
BEGIN
    -- Check if there's an existing prescription for this doctor-patient combination
    SELECT COUNT(*) INTO v_count
    FROM PRESCRIPTION
    WHERE DoctorID = :NEW.DoctorID
    AND PatientID = :NEW.PatientID
    AND PrescID <> NVL(:NEW.PrescID, 'NONE');
    
    IF v_count > 0 THEN
        -- Get the PrescID of the old prescription
        SELECT PrescID INTO v_old_presc_id
        FROM PRESCRIPTION
        WHERE DoctorID = :NEW.DoctorID
        AND PatientID = :NEW.PatientID
        AND PrescID <> NVL(:NEW.PrescID, 'NONE');
        
        -- Delete the associated prescription details first (due to foreign key constraint)
        DELETE FROM PRESC_DETAILS
        WHERE PrescID = v_old_presc_id;
        
        -- Then delete the old prescription
        DELETE FROM PRESCRIPTION
        WHERE PrescID = v_old_presc_id;
    END IF;
END;
/



-- Trigger to ensure each patient has a primary physician
CREATE OR REPLACE TRIGGER trg_patient_has_physician
AFTER INSERT OR UPDATE ON PATIENT
FOR EACH ROW
DECLARE
    doctor_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO doctor_count 
    FROM DOCTOR 
    WHERE AadharID = :NEW.PhysicianID;
    
    IF doctor_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Primary physician does not exist');
    END IF;
    
    -- Also insert into TREATED_BY to maintain relationship
    INSERT INTO TREATED_BY (DoctorID, PatientID)
    VALUES (:NEW.PhysicianID, :NEW.AadharID);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        NULL; -- Relationship already exists
END;
/

-- Trigger to ensure a pharmacy sells at least 10 drugs
CREATE OR REPLACE TRIGGER trg_pharmacy_min_drugs
AFTER DELETE ON SELLS
FOR EACH ROW
DECLARE
    drug_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO drug_count
    FROM SELLS
    WHERE PName = :OLD.PName;
    
    IF drug_count <= 10 THEN
        RAISE_APPLICATION_ERROR(-20003, 'A pharmacy must sell at least 10 drugs');
    END IF;
END;
/

-- Procedures for the required functionality

-- 1. Adding/Updating/Deleting new data

-- Updating procedures
-- Updating Prescription Table details
CREATE OR REPLACE PROCEDURE update_prescription(
    presc_id VARCHAR2,
    doctor_id VARCHAR2,
    patient_id VARCHAR2,
    p_date DATE
) AS 
BEGIN
    UPDATE PRESCRIPTION
    SET DoctorID = doctor_id, PatientID = patient_id, PDate = p_date
    WHERE PrescID = presc_id;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No prescription found with ID: ' || presc_id);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Prescription updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Updating Presc_Details table
CREATE OR REPLACE PROCEDURE update_presc_details(
    presc_id VARCHAR2,
    c_name_ex VARCHAR2,
    drug_ex VARCHAR2,
    c_name_new VARCHAR2,
    drug_new VARCHAR2,
    quantity_new NUMBER
) AS 
BEGIN
    UPDATE PRESC_DETAILS
    SET CName = c_name_new, Drug = drug_new, Quantity = quantity_new
    WHERE PrescID = presc_id AND CName = c_name_ex AND Drug = drug_ex;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No prescription detail found with the specified criteria');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Prescription detail updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Updating Patient details
CREATE OR REPLACE PROCEDURE update_patient(
    p_aadhar VARCHAR2,
    p_name VARCHAR2,
    p_age NUMBER,
    p_address VARCHAR2,
    p_physician VARCHAR2
) AS 
BEGIN
    UPDATE PATIENT
    SET Name = p_name, Age = p_age, Address = p_address, PhysicianID = p_physician
    WHERE AadharID = p_aadhar; 
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No patient found with Aadhar ID: ' || p_aadhar);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Patient updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Updating doctor details
CREATE OR REPLACE PROCEDURE update_doctor(
    d_aadhar VARCHAR2,
    d_name VARCHAR2,
    d_spec VARCHAR2,
    d_exp NUMBER
) AS 
BEGIN
    UPDATE DOCTOR
    SET Name = d_name, Speciality = d_spec, Yrs_Experience = d_exp
    WHERE AadharID = d_aadhar;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No doctor found with Aadhar ID: ' || d_aadhar);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Doctor updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Updating drug details
CREATE OR REPLACE PROCEDURE update_drug(
    c_name_ex VARCHAR2,
    trade_name_ex VARCHAR2,
    c_name_new VARCHAR2,
    trade_name_new VARCHAR2,
    formula_new VARCHAR2
) AS 
BEGIN
    UPDATE DRUG
    SET CName = c_name_new, Trade_Name = trade_name_new, Formula = formula_new
    WHERE CName = c_name_ex AND Trade_Name = trade_name_ex;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No drug found with the specified criteria');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Drug updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

CREATE OR REPLACE PROCEDURE update_treated_by(
    doctor_id_ex VARCHAR2,
    patient_id_ex VARCHAR2,
    doctor_id_new VARCHAR2,
    patient_id_new VARCHAR2
) AS 
BEGIN
    UPDATE TREATED_BY
    SET DoctorID = doctor_id_new, PatientID = patient_id_new
    WHERE DoctorID = doctor_id_ex AND PatientID = patient_id_ex;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No relationship found with the specified criteria');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Relationship updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Updating selling price of a drug in pharmacy
CREATE OR REPLACE PROCEDURE update_selling_price(
    p_name VARCHAR2,
    c_name VARCHAR2,
    drug VARCHAR2,
    price_new NUMBER
) AS 
BEGIN
    UPDATE SELLS
    SET Price = price_new
    WHERE PName = p_name AND CName = c_name AND Drug = drug;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No drug sale found with the specified criteria');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Price updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Updating pharmacy details
CREATE OR REPLACE PROCEDURE update_pharmacy(
    ph_name_ex VARCHAR2,
    ph_name_new VARCHAR2,
    ph_address_new VARCHAR2,
    ph_phone_new VARCHAR2
) AS 
BEGIN 
    UPDATE PHARMACY
    SET PName = ph_name_new, PAddress = ph_address_new, PPhone = ph_phone_new
    WHERE PName = ph_name_ex;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No pharmacy found with name: ' || ph_name_ex);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Pharmacy updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Updating pharma_company details
CREATE OR REPLACE PROCEDURE update_pharma_company(
    pc_name_ex VARCHAR2,
    pc_name_new VARCHAR2,
    pc_phone_new VARCHAR2
) AS 
BEGIN
    UPDATE PHARMACEUTICAL_COMPANY
    SET CName = pc_name_new, CPhone = pc_phone_new
    WHERE CName = pc_name_ex;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No pharmaceutical company found with name: ' || pc_name_ex);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Pharmaceutical company updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Update contract details
CREATE OR REPLACE PROCEDURE update_contract_details(
    p_name VARCHAR2,
    c_name VARCHAR2,
    start_date_ex DATE,
    end_date_ex DATE,
    start_date_new DATE,
    end_date_new DATE,
    content_new VARCHAR2,
    new_supervisor VARCHAR2
) AS
BEGIN
    UPDATE CONTRACTS
    SET Supervisor = new_supervisor, Start_Date = start_date_new, End_Date = end_date_new, Content = content_new
    WHERE PName = p_name
      AND CName = c_name
      AND Start_Date = start_date_ex
      AND End_Date = end_date_ex;

    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No contract found with the specified details');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Contract Details updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Delete Procedures tuple
CREATE OR REPLACE PROCEDURE delete_prescription(
    presc_id VARCHAR2
) AS 
BEGIN
    DELETE FROM PRESCRIPTION
    WHERE PrescID = presc_id;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No prescription found with ID: ' || presc_id);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Prescription deleted successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Deleting presc_details tuple
CREATE OR REPLACE PROCEDURE delete_presc_details(
    presc_id VARCHAR2,
    c_name VARCHAR2,
    drug VARCHAR2
) AS 
BEGIN 
    DELETE FROM PRESC_DETAILS
    WHERE PrescID = presc_id AND CName = c_name AND Drug = drug;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No prescription detail found with the specified criteria');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Prescription detail deleted successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Delete patient
CREATE OR REPLACE PROCEDURE delete_patient(
    p_aadhar VARCHAR2
) AS 
BEGIN
    DELETE FROM PATIENT
    WHERE AadharID = p_aadhar;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No patient found with Aadhar ID: ' || p_aadhar);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Patient deleted successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Delete doctor
CREATE OR REPLACE PROCEDURE delete_doctor(
    d_aadhar VARCHAR2
) AS 
BEGIN 
    DELETE FROM DOCTOR 
    WHERE AadharID = d_aadhar;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No doctor found with Aadhar ID: ' || d_aadhar);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Doctor deleted successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Delete drug entity tuple
CREATE OR REPLACE PROCEDURE delete_drug(
    c_name VARCHAR2,
    trade_name VARCHAR2
) AS 
BEGIN
    DELETE FROM DRUG
    WHERE CName = c_name AND Trade_Name = trade_name;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No drug found with the specified criteria');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Drug deleted successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Delete treated by tuple
CREATE OR REPLACE PROCEDURE delete_from_treated_by(
    doctor_id VARCHAR2,
    patient_id VARCHAR2
) AS 
BEGIN
    DELETE FROM TREATED_BY
    WHERE DoctorID = doctor_id AND PatientID = patient_id;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No relationship found with the specified criteria');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Relationship deleted successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Delete contract
CREATE OR REPLACE PROCEDURE delete_contract(
    p_name VARCHAR2,
    c_name VARCHAR2,
    start_date DATE,
    end_date DATE
) AS 
BEGIN
    DELETE FROM CONTRACTS
    WHERE PName = p_name AND CName = c_name AND Start_Date = start_date AND End_Date = end_date;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No contract found with the specified criteria');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Contract deleted successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Delete sell entity tuple
CREATE OR REPLACE PROCEDURE delete_sells(
    p_name VARCHAR2,
    c_name VARCHAR2,
    drug VARCHAR2
) AS 
BEGIN 
    DELETE FROM SELLS 
    WHERE PName = p_name AND CName = c_name AND Drug = drug;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No drug sale found with the specified criteria');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Drug sale deleted successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Delete pharmacy
CREATE OR REPLACE PROCEDURE delete_pharmacy(
    p_name VARCHAR2
) AS 
BEGIN 
    DELETE FROM PHARMACY
    WHERE PName = p_name;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No pharmacy found with name: ' || p_name);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Pharmacy deleted successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Delete pharma company
CREATE OR REPLACE PROCEDURE delete_pharma_company(
    c_name VARCHAR2
) AS 
BEGIN 
    DELETE FROM PHARMACEUTICAL_COMPANY
    WHERE CName = c_name;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No pharmaceutical company found with name: ' || c_name);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Pharmaceutical company deleted successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Add new pharmacy
CREATE OR REPLACE PROCEDURE add_pharmacy(
    p_name VARCHAR2,
    p_address VARCHAR2,
    p_phone VARCHAR2
) AS
BEGIN
    INSERT INTO PHARMACY (PName, PAddress, PPhone)
    VALUES (p_name, p_address, p_phone);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Pharmacy added successfully');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Pharmacy with this name already exists');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Add new pharmaceutical company
CREATE OR REPLACE PROCEDURE add_pharma_company(
    c_name VARCHAR2,
    c_phone VARCHAR2
) AS
BEGIN
    INSERT INTO PHARMACEUTICAL_COMPANY (CName, CPhone)
    VALUES (c_name, c_phone);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Pharmaceutical company added successfully');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Company with this name already exists');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Add new patient
CREATE OR REPLACE PROCEDURE add_patient(
    p_aadhar VARCHAR2,
    p_name VARCHAR2,
    p_age NUMBER,
    p_address VARCHAR2,
    p_physician VARCHAR2
) AS
BEGIN
    INSERT INTO PATIENT (AadharID, Name, Age, Address, PhysicianID)
    VALUES (p_aadhar, p_name, p_age, p_address, p_physician);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Patient added successfully');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Patient with this Aadhar ID already exists');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Add new doctor
CREATE OR REPLACE PROCEDURE add_doctor(
    d_aadhar VARCHAR2,
    d_name VARCHAR2,
    d_speciality VARCHAR2,
    d_experience NUMBER
) AS
BEGIN
    INSERT INTO DOCTOR (AadharID, Name, Speciality, Yrs_Experience)
    VALUES (d_aadhar, d_name, d_speciality, d_experience);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Doctor added successfully');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Doctor with this Aadhar ID already exists');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Add new drug
CREATE OR REPLACE PROCEDURE add_drug(
    c_name VARCHAR2,
    trade_name VARCHAR2,
    formula VARCHAR2
) AS
BEGIN
    INSERT INTO DRUG (CName, Trade_Name, Formula)
    VALUES (c_name, trade_name, formula);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Drug added successfully');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Drug with this trade name already exists for this company');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Add drug to pharmacy inventory
CREATE OR REPLACE PROCEDURE add_drug_to_pharmacy(
    p_name VARCHAR2,
    c_name VARCHAR2,
    drug VARCHAR2,
    price NUMBER
) AS
    drug_count NUMBER;
BEGIN
    -- Check if the drug exists
    SELECT COUNT(*) INTO drug_count
    FROM DRUG
    WHERE CName = c_name AND Trade_Name = drug;
    
    IF drug_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Drug does not exist');
    END IF;
    
    INSERT INTO SELLS (PName, CName, Drug, Price)
    VALUES (p_name, c_name, drug, price);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Drug added to pharmacy successfully');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('This drug is already sold at this pharmacy');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Add new contract
CREATE OR REPLACE PROCEDURE add_contract(
    p_name VARCHAR2,
    c_name VARCHAR2,
    start_date DATE,
    end_date DATE,
    supervisor VARCHAR2,
    content CLOB
) AS
BEGIN
    INSERT INTO CONTRACTS (PName, CName, Start_Date, End_Date, Supervisor, Content)
    VALUES (p_name, c_name, start_date, end_date, supervisor, content);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Contract added successfully');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('A contract already exists between this pharmacy and company with the given start and end date');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Add new prescription
CREATE OR REPLACE PROCEDURE add_prescription(
    presc_id VARCHAR2,
    doctor_id VARCHAR2,
    patient_id VARCHAR2,
    presc_date DATE
) AS
    v_count NUMBER;
BEGIN
    -- Check if prescription already exists for this doctor-patient-date
    SELECT COUNT(*) INTO v_count
    FROM PRESCRIPTION
    WHERE DoctorID = doctor_id
    AND PatientID = patient_id
    AND PDate = presc_date;
    
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('A prescription already exists for this doctor-patient-date combination');
        RETURN;
    END IF;
    
    INSERT INTO PRESCRIPTION (PrescID, DoctorID, PatientID, PDate)
    VALUES (presc_id, doctor_id, patient_id, presc_date);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Prescription added successfully');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('This prescription ID already exists or the doctor has already prescribed for this patient on this date');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Add drug to prescription
CREATE OR REPLACE PROCEDURE add_drug_to_prescription(
    presc_id VARCHAR2,
    c_name VARCHAR2,
    drug VARCHAR2,
    quantity NUMBER
) AS
BEGIN
    INSERT INTO PRESC_DETAILS (PrescID, CName, Drug, Quantity)
    VALUES (presc_id, c_name, drug, quantity);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Drug added to prescription successfully');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('This drug is already in the prescription');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Update supervisor for a contract
CREATE OR REPLACE PROCEDURE update_contract_supervisor(
    p_name         VARCHAR2,
    c_name         VARCHAR2,
    start_date_ex     DATE,
    end_date_ex       DATE,
    new_supervisor VARCHAR2
) AS
BEGIN
    UPDATE CONTRACTS
    SET Supervisor = new_supervisor
    WHERE PName = p_name
      AND CName = c_name
      AND Start_Date = start_date_ex
      AND End_Date = end_date_ex;

    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No contract found with the specified details');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Contract Supervisor updated successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- 2. Generate report on prescriptions of a patient in a given period
CREATE OR REPLACE PROCEDURE get_patient_prescriptions(
    p_patient_id VARCHAR2,
    p_start_date DATE,
    p_end_date DATE
) AS
    CURSOR c_prescriptions IS
        SELECT p.PrescID, p.PDate, d.Name AS DoctorName, pd.CName, pd.Drug, pd.Quantity
        FROM PRESCRIPTION p
        JOIN DOCTOR d ON p.DoctorID = d.AadharID
        JOIN PRESC_DETAILS pd ON p.PrescID = pd.PrescID
        WHERE p.PatientID = p_patient_id
        AND p.PDate BETWEEN p_start_date AND p_end_date
        ORDER BY p.PDate DESC;
    
    v_patient_name PATIENT.Name%TYPE;
    v_presc_count NUMBER := 0;
BEGIN
    -- Get patient name
    SELECT Name INTO v_patient_name
    FROM PATIENT
    WHERE AadharID = p_patient_id;
    
    DBMS_OUTPUT.PUT_LINE('Prescription Report for Patient: ' || v_patient_name);
    DBMS_OUTPUT.PUT_LINE('Period: ' || TO_CHAR(p_start_date, 'DD-MON-YYYY') || ' to ' || TO_CHAR(p_end_date, 'DD-MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    
    FOR r IN c_prescriptions LOOP
        DBMS_OUTPUT.PUT_LINE('Prescription ID: ' || r.PrescID);
        DBMS_OUTPUT.PUT_LINE('Date: ' || TO_CHAR(r.PDate, 'DD-MON-YYYY'));
        DBMS_OUTPUT.PUT_LINE('Doctor: ' || r.DoctorName);
        DBMS_OUTPUT.PUT_LINE('Drug: ' || r.Drug || ' (' || r.CName || ')');
        DBMS_OUTPUT.PUT_LINE('Quantity: ' || r.Quantity);
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
        v_presc_count := v_presc_count + 1;
    END LOOP;
    
    IF v_presc_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No prescriptions found for this patient in the specified period.');
    /*ELSE
        DBMS_OUTPUT.PUT_LINE('Total drugs prescribed: ' || v_presc_count);*/
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Patient not found');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- 3. Print details of a prescription for a given patient for a given date
CREATE OR REPLACE PROCEDURE get_prescription_details(
    p_patient_id VARCHAR2,
    p_date DATE
) AS
    CURSOR c_presc_details IS
        SELECT pd.CName, pd.Drug, pd.Quantity, doc.Name AS DoctorName, p.PrescID
        FROM PRESCRIPTION p
        JOIN PRESC_DETAILS pd ON p.PrescID = pd.PrescID
        JOIN DOCTOR doc ON p.DoctorID = doc.AadharID
        WHERE p.PatientID = p_patient_id
        AND p.PDate = p_date;
    
    v_patient_name PATIENT.Name%TYPE;
    v_found BOOLEAN := FALSE;
    v_presc_id PRESCRIPTION.PrescID%TYPE;
    v_doctor_name DOCTOR.Name%TYPE;
BEGIN
    -- Get patient name
    SELECT Name INTO v_patient_name
    FROM PATIENT
    WHERE AadharID = p_patient_id;
    
    DBMS_OUTPUT.PUT_LINE('Prescription Details for Patient: ' || v_patient_name);
    DBMS_OUTPUT.PUT_LINE('Date: ' || TO_CHAR(p_date, 'DD-MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    
    FOR r IN c_presc_details LOOP
        IF NOT v_found THEN
            v_presc_id := r.PrescID;
            v_doctor_name := r.DoctorName;
            DBMS_OUTPUT.PUT_LINE('Prescription ID: ' || v_presc_id);
            DBMS_OUTPUT.PUT_LINE('Doctor: ' || v_doctor_name);
            DBMS_OUTPUT.PUT_LINE('Drugs prescribed:');
            v_found := TRUE;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('- ' || r.Drug || ' (' || r.CName || '), Quantity: ' || r.Quantity);
    END LOOP;
    
    IF NOT v_found THEN
        DBMS_OUTPUT.PUT_LINE('No prescription found for this patient on the specified date.');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Patient not found');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- 4. Get the details of drugs produced by a pharmaceutical company
CREATE OR REPLACE PROCEDURE get_company_drugs(
    p_company_name VARCHAR2
) AS
    CURSOR c_drugs IS
        SELECT Trade_Name, Formula
        FROM DRUG
        WHERE CName = p_company_name
        ORDER BY Trade_Name;
    
    v_company_phone PHARMACEUTICAL_COMPANY.CPhone%TYPE;
    v_drug_count NUMBER := 0;
BEGIN
    -- Get company phone
    SELECT CPhone INTO v_company_phone
    FROM PHARMACEUTICAL_COMPANY
    WHERE CName = p_company_name;
    
    DBMS_OUTPUT.PUT_LINE('Drugs produced by: ' || p_company_name);
    DBMS_OUTPUT.PUT_LINE('Phone: ' || v_company_phone);
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    
    FOR r IN c_drugs LOOP
        DBMS_OUTPUT.PUT_LINE('Trade Name: ' || r.Trade_Name);
        DBMS_OUTPUT.PUT_LINE('Formula: ' || r.Formula);
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
        v_drug_count := v_drug_count + 1;
    END LOOP;
    
    IF v_drug_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No drugs found for this pharmaceutical company.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Total drugs: ' || v_drug_count);
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Company not found');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- 5. Print the stock position of a pharmacy
CREATE OR REPLACE PROCEDURE get_pharmacy_stock(
    p_pharmacy_name VARCHAR2
) AS
    CURSOR c_stock IS
        SELECT s.CName, s.Drug, s.Price, d.Formula
        FROM SELLS s
        JOIN DRUG d ON s.CName = d.CName AND s.Drug = d.Trade_Name
        WHERE s.PName = p_pharmacy_name
        ORDER BY s.CName, s.Drug;
    
    v_pharmacy_addr PHARMACY.PAddress%TYPE;
    v_pharmacy_phone PHARMACY.PPhone%TYPE;
    v_drug_count NUMBER := 0;
BEGIN
    -- Get pharmacy details
    SELECT PAddress, PPhone INTO v_pharmacy_addr, v_pharmacy_phone
    FROM PHARMACY
    WHERE PName = p_pharmacy_name;
    
    DBMS_OUTPUT.PUT_LINE('Stock Position for Pharmacy: ' || p_pharmacy_name);
    DBMS_OUTPUT.PUT_LINE('Address: ' || v_pharmacy_addr);
    DBMS_OUTPUT.PUT_LINE('Phone: ' || v_pharmacy_phone);
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Drug                  | Company                | Price      | Formula');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    
    FOR r IN c_stock LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(r.Drug, 22, ' ') || '| ' || 
                           RPAD(r.CName, 24, ' ') || '| ' || 
                           LPAD(TO_CHAR(r.Price, '9999.99'), 10, ' ') || ' | ' || 
                           r.Formula);
        v_drug_count := v_drug_count + 1;
    END LOOP;
    
    IF v_drug_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No drugs found in this pharmacy.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Total drugs: ' || v_drug_count);
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Pharmacy not found');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- 6. Print the contact details of a pharmacy-pharmaceutical company
CREATE OR REPLACE PROCEDURE get_contract_details(
    p_pharmacy_name VARCHAR2,
    p_company_name VARCHAR2
) AS
    v_start_date CONTRACTS.Start_Date%TYPE;
    v_end_date CONTRACTS.End_Date%TYPE;
    v_supervisor CONTRACTS.Supervisor%TYPE;
    v_content CONTRACTS.Content%TYPE;
    v_pharmacy_phone PHARMACY.PPhone%TYPE;
    v_company_phone PHARMACEUTICAL_COMPANY.CPhone%TYPE;
BEGIN
    -- Get pharmacy phone
    SELECT PPhone INTO v_pharmacy_phone
    FROM PHARMACY
    WHERE PName = p_pharmacy_name;
    
    -- Get company phone
    SELECT CPhone INTO v_company_phone
    FROM PHARMACEUTICAL_COMPANY
    WHERE CName = p_company_name;
    
    -- Get contract details
    SELECT Start_Date, End_Date, Supervisor, Content
    INTO v_start_date, v_end_date, v_supervisor, v_content
    FROM CONTRACTS
    WHERE PName = p_pharmacy_name AND CName = p_company_name;
    
    DBMS_OUTPUT.PUT_LINE('Contract Details:');
    DBMS_OUTPUT.PUT_LINE('Pharmacy: ' || p_pharmacy_name || ' (Phone: ' || v_pharmacy_phone || ')');
    DBMS_OUTPUT.PUT_LINE('Company: ' || p_company_name || ' (Phone: ' || v_company_phone || ')');
    DBMS_OUTPUT.PUT_LINE('Start Date: ' || TO_CHAR(v_start_date, 'DD-MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE('End Date: ' || TO_CHAR(v_end_date, 'DD-MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE('Supervisor: ' || v_supervisor);
    DBMS_OUTPUT.PUT_LINE('Contract Content:');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(v_content);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No contract found between the specified pharmacy and company');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- 7. Print the list of patients for a given doctor
CREATE OR REPLACE PROCEDURE get_doctor_patients(
    p_doctor_id VARCHAR2
) AS
    CURSOR c_patients IS
        SELECT p.AadharID, p.Name, p.Age, p.Address, 
               CASE WHEN p.PhysicianID = p_doctor_id THEN 'Yes' ELSE 'No' END AS IsPrimaryPhysician
        FROM PATIENT p
        JOIN TREATED_BY tb ON p.AadharID = tb.PatientID
        WHERE tb.DoctorID = p_doctor_id
        ORDER BY p.Name;
    
    v_doctor_name DOCTOR.Name%TYPE;
    v_doctor_speciality DOCTOR.Speciality%TYPE;
    v_patient_count NUMBER := 0;
BEGIN
    -- Get doctor details
    SELECT Name, Speciality INTO v_doctor_name, v_doctor_speciality
    FROM DOCTOR
    WHERE AadharID = p_doctor_id;
    
    DBMS_OUTPUT.PUT_LINE('Patients for Doctor: ' || v_doctor_name);
    DBMS_OUTPUT.PUT_LINE('Speciality: ' || v_doctor_speciality);
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('AadharID         | Name                  | Age   | Primary Physician | Address');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    
    FOR r IN c_patients LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(r.AadharID, 17, ' ') || '| ' || 
                           RPAD(r.Name, 22, ' ') || '| ' || 
                           LPAD(TO_CHAR(r.Age), 6, ' ') || ' | ' || 
                           RPAD(r.IsPrimaryPhysician, 17, ' ') || '| ' || 
                           r.Address);
        v_patient_count := v_patient_count + 1;
    END LOOP;
    
    IF v_patient_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No patients found for this doctor.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Total patients: ' || v_patient_count);
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Doctor not found');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- PL/SQL block to insert dummy data using the defined procedures
BEGIN

-- Insert pharmaceutical companies
    add_pharma_company('Sun Pharma', '9123456780');
    add_pharma_company('Cipla', '9123456781');
    add_pharma_company('Dr. Reddy', '9123456782');
    add_pharma_company('Ranbaxy', '9123456783');
    add_pharma_company('Pfizer', '9123456784');
    add_pharma_company('Abbott', '9123456785');
    add_pharma_company('GSK', '9123456786');
    
    -- Insert pharmacies
    add_pharmacy('Nova Central', 'MG Road, Bangalore', '8123456780');
    add_pharmacy('Nova East', 'Whitefield, Bangalore', '8123456781');
    add_pharmacy('Nova West', 'Malleswaram, Bangalore', '8123456782');
    add_pharmacy('Nova North', 'Hebbal, Bangalore', '8123456783');
    add_pharmacy('Nova South', 'Jayanagar, Bangalore', '8123456784');
    
    -- Insert doctors
    add_doctor('123456789012', 'Dr. Sharma', 'Cardiology', 15);
    add_doctor('223456789012', 'Dr. Patel', 'Neurology', 12);
    add_doctor('323456789012', 'Dr. Singh', 'Pediatrics', 8);
    add_doctor('423456789012', 'Dr. Gupta', 'Orthopedics', 10);
    add_doctor('523456789012', 'Dr. Kumar', 'Dermatology', 7);
    add_doctor('623456789012', 'Dr. Joshi', 'General Medicine', 20);
    add_doctor('723456789012', 'Dr. Mehra', 'ENT', 9);
    add_doctor('823456789012', 'Dr. Verma', 'Gynecology', 11);
    
    -- Insert patients
    add_patient('987654321012', 'Ravi Kumar', 35, 'Indiranagar, Bangalore', '123456789012');
    add_patient('887654321012', 'Anjali Sharma', 28, 'Koramangala, Bangalore', '223456789012');
    add_patient('787654321012', 'Suresh Patel', 45, 'HSR Layout, Bangalore', '323456789012');
    add_patient('687654321012', 'Priya Singh', 30, 'BTM Layout, Bangalore', '423456789012');
    add_patient('587654321012', 'Mohan Reddy', 55, 'JP Nagar, Bangalore', '523456789012');
    add_patient('487654321012', 'Kavita Gupta', 42, 'Marathahalli, Bangalore', '623456789012');
    add_patient('387654321012', 'Rajesh Khanna', 38, 'Electronic City, Bangalore', '723456789012');
    add_patient('287654321012', 'Sunita Jain', 50, 'Yelahanka, Bangalore', '823456789012');
    add_patient('187654321012', 'Amit Shah', 29, 'Banashankari, Bangalore', '123456789012');
    add_patient('087654321012', 'Pooja Verma', 33, 'Basavanagudi, Bangalore', '223456789012');
    
    -- Make additional doctor-patient relationships using TREATED_BY
    -- This is handled automatically by the add_patient procedure, but we can add more relationships
    INSERT INTO TREATED_BY (DoctorID, PatientID) VALUES ('223456789012', '987654321012');
    INSERT INTO TREATED_BY (DoctorID, PatientID) VALUES ('323456789012', '887654321012');
    INSERT INTO TREATED_BY (DoctorID, PatientID) VALUES ('423456789012', '787654321012');
    INSERT INTO TREATED_BY (DoctorID, PatientID) VALUES ('523456789012', '687654321012');
    
    -- Insert drugs
    add_drug('Sun Pharma', 'Paracetamol', 'C8H9NO2');
    add_drug('Sun Pharma', 'Amoxicillin', 'C16H19N3O5S');
    add_drug('Sun Pharma', 'Aspirin', 'C9H8O4');
    add_drug('Sun Pharma', 'Cetirizine', 'C21H25ClN2O3');
    add_drug('Cipla', 'Azithromycin', 'C38H72N2O12');
    add_drug('Cipla', 'Pantoprazole', 'C16H15F2N3O4S');
    add_drug('Cipla', 'Montelukast', 'C35H36ClNO3S');
    add_drug('Cipla', 'Fexofenadine', 'C32H39NO4');
    add_drug('Dr. Reddy', 'Metformin', 'C4H11N5');
    add_drug('Dr. Reddy', 'Atorvastatin', 'C33H35FN2O5');
    add_drug('Dr. Reddy', 'Glimepiride', 'C24H34N4O5S');
    add_drug('Dr. Reddy', 'Ondansetron', 'C18H19N3O');
    add_drug('Ranbaxy', 'Lisinopril', 'C21H31N3O5');
    add_drug('Ranbaxy', 'Losartan', 'C22H23ClN6O');
    add_drug('Ranbaxy', 'Clopidogrel', 'C16H16ClNO2S');
    add_drug('Ranbaxy', 'Ramipril', 'C23H32N2O5');
    add_drug('Pfizer', 'Lipitor', 'C33H35FN2O5');
    add_drug('Pfizer', 'Viagra', 'C22H30N6O4S');
    add_drug('Pfizer', 'Zoloft', 'C17H17Cl2N');
    add_drug('Pfizer', 'Lyrica', 'C8H17NO2');
    add_drug('Abbott', 'Brufen', 'C13H18O2');
    add_drug('Abbott', 'Thyronorm', 'C15H11I4NO4');
    add_drug('Abbott', 'Duphaston', 'C21H28O2');
    add_drug('GSK', 'Augmentin', 'C16H19N3O5S');
    add_drug('GSK', 'Ceftum', 'C16H17N5O7S2');
    add_drug('GSK', 'Cetzine', 'C21H25ClN2O3');
    
    -- Add drugs to pharmacies (each pharmacy needs at least 10 drugs)
    -- Nova Central
    add_drug_to_pharmacy('Nova Central', 'Sun Pharma', 'Paracetamol', 25.50);
    add_drug_to_pharmacy('Nova Central', 'Sun Pharma', 'Amoxicillin', 120.75);
    add_drug_to_pharmacy('Nova Central', 'Sun Pharma', 'Aspirin', 15.25);
    add_drug_to_pharmacy('Nova Central', 'Cipla', 'Azithromycin', 230.00);
    add_drug_to_pharmacy('Nova Central', 'Cipla', 'Pantoprazole', 85.50);
    add_drug_to_pharmacy('Nova Central', 'Dr. Reddy', 'Metformin', 45.25);
    add_drug_to_pharmacy('Nova Central', 'Dr. Reddy', 'Atorvastatin', 175.00);
    add_drug_to_pharmacy('Nova Central', 'Ranbaxy', 'Lisinopril', 65.50);
    add_drug_to_pharmacy('Nova Central', 'Ranbaxy', 'Losartan', 95.75);
    add_drug_to_pharmacy('Nova Central', 'Pfizer', 'Lipitor', 350.00);
    add_drug_to_pharmacy('Nova Central', 'Pfizer', 'Viagra', 450.25);
    add_drug_to_pharmacy('Nova Central', 'Abbott', 'Brufen', 35.50);
    
    -- Nova East
    add_drug_to_pharmacy('Nova East', 'Sun Pharma', 'Paracetamol', 27.50);
    add_drug_to_pharmacy('Nova East', 'Sun Pharma', 'Amoxicillin', 125.75);
    add_drug_to_pharmacy('Nova East', 'Cipla', 'Azithromycin', 245.00);
    add_drug_to_pharmacy('Nova East', 'Cipla', 'Montelukast', 155.50);
    add_drug_to_pharmacy('Nova East', 'Dr. Reddy', 'Glimepiride', 85.25);
    add_drug_to_pharmacy('Nova East', 'Dr. Reddy', 'Ondansetron', 115.00);
    add_drug_to_pharmacy('Nova East', 'Ranbaxy', 'Clopidogrel', 225.50);
    add_drug_to_pharmacy('Nova East', 'Ranbaxy', 'Ramipril', 135.75);
    add_drug_to_pharmacy('Nova East', 'Pfizer', 'Zoloft', 370.00);
    add_drug_to_pharmacy('Nova East', 'Pfizer', 'Lyrica', 420.25);
    add_drug_to_pharmacy('Nova East', 'Abbott', 'Thyronorm', 95.50);
    add_drug_to_pharmacy('Nova East', 'GSK', 'Augmentin', 165.75);
    
    -- Nova West
    add_drug_to_pharmacy('Nova West', 'Sun Pharma', 'Cetirizine', 35.50);
    add_drug_to_pharmacy('Nova West', 'Sun Pharma', 'Aspirin', 16.25);
    add_drug_to_pharmacy('Nova West', 'Cipla', 'Fexofenadine', 145.00);
    add_drug_to_pharmacy('Nova West', 'Cipla', 'Pantoprazole', 87.50);
    add_drug_to_pharmacy('Nova West', 'Dr. Reddy', 'Metformin', 47.25);
    add_drug_to_pharmacy('Nova West', 'Dr. Reddy', 'Atorvastatin', 177.00);
    add_drug_to_pharmacy('Nova West', 'Ranbaxy', 'Lisinopril', 67.50);
    add_drug_to_pharmacy('Nova West', 'Ranbaxy', 'Losartan', 97.75);
    add_drug_to_pharmacy('Nova West', 'Pfizer', 'Lipitor', 355.00);
    add_drug_to_pharmacy('Nova West', 'GSK', 'Ceftum', 245.75);
    add_drug_to_pharmacy('Nova West', 'Abbott', 'Duphaston', 310.50);
    add_drug_to_pharmacy('Nova West', 'GSK', 'Cetzine', 55.25);
    
    -- Nova North
    add_drug_to_pharmacy('Nova North', 'Sun Pharma', 'Paracetamol', 24.50);
    add_drug_to_pharmacy('Nova North', 'Sun Pharma', 'Amoxicillin', 118.75);
    add_drug_to_pharmacy('Nova North', 'Cipla', 'Azithromycin', 228.00);
    add_drug_to_pharmacy('Nova North', 'Cipla', 'Montelukast', 152.50);
    add_drug_to_pharmacy('Nova North', 'Dr. Reddy', 'Glimepiride', 82.25);
    add_drug_to_pharmacy('Nova North', 'Dr. Reddy', 'Ondansetron', 112.00);
    add_drug_to_pharmacy('Nova North', 'Ranbaxy', 'Clopidogrel', 222.50);
    add_drug_to_pharmacy('Nova North', 'Ranbaxy', 'Ramipril', 132.75);
    add_drug_to_pharmacy('Nova North', 'Pfizer', 'Zoloft', 365.00);
    add_drug_to_pharmacy('Nova North', 'GSK', 'Augmentin', 162.75);
    add_drug_to_pharmacy('Nova North', 'Abbott', 'Thyronorm', 92.50);
    add_drug_to_pharmacy('Nova North', 'Abbott', 'Brufen', 34.25);
    
    -- Nova South
    add_drug_to_pharmacy('Nova South', 'Sun Pharma', 'Cetirizine', 36.50);
    add_drug_to_pharmacy('Nova South', 'Sun Pharma', 'Aspirin', 17.25);
    add_drug_to_pharmacy('Nova South', 'Cipla', 'Fexofenadine', 146.00);
    add_drug_to_pharmacy('Nova South', 'Cipla', 'Pantoprazole', 88.50);
    add_drug_to_pharmacy('Nova South', 'Dr. Reddy', 'Metformin', 48.25);
    add_drug_to_pharmacy('Nova South', 'Dr. Reddy', 'Atorvastatin', 178.00);
    add_drug_to_pharmacy('Nova South', 'Ranbaxy', 'Lisinopril', 68.50);
    add_drug_to_pharmacy('Nova South', 'Ranbaxy', 'Losartan', 98.75);
    add_drug_to_pharmacy('Nova South', 'Pfizer', 'Lipitor', 356.00);
    add_drug_to_pharmacy('Nova South', 'Pfizer', 'Viagra', 455.25);
    add_drug_to_pharmacy('Nova South', 'GSK', 'Ceftum', 246.75);
    add_drug_to_pharmacy('Nova South', 'GSK', 'Cetzine', 56.25);
    
    -- Add contracts between pharmacies and pharmaceutical companies
    add_contract('Nova Central', 'Sun Pharma', 
                TO_DATE('01-01-2025', 'DD-MM-YYYY'), 
                TO_DATE('31-12-2025', 'DD-MM-YYYY'), 
                'Rajiv Mehta', 
                'Contract for supply of Sun Pharma medications to Nova Central for the year 2025');
                
    add_contract('Nova Central', 'Cipla', 
                TO_DATE('01-02-2025', 'DD-MM-YYYY'), 
                TO_DATE('31-01-2026', 'DD-MM-YYYY'), 
                'Amit Kumar', 
                'Contract for supply of Cipla medications to Nova Central from Feb 2025 to Jan 2026');
                
    add_contract('Nova East', 'Ranbaxy', 
                TO_DATE('01-03-2025', 'DD-MM-YYYY'), 
                TO_DATE('28-02-2026', 'DD-MM-YYYY'), 
                'Priya Sharma', 
                'Contract for supply of Ranbaxy medications to Nova East from Mar 2025 to Feb 2026');
                
    add_contract('Nova West', 'Pfizer', 
                TO_DATE('01-01-2025', 'DD-MM-YYYY'), 
                TO_DATE('30-06-2025', 'DD-MM-YYYY'), 
                'Sanjay Gupta', 
                'Six-month contract for supply of Pfizer medications to Nova West');
                
    add_contract('Nova North', 'Dr. Reddy', 
                TO_DATE('01-04-2025', 'DD-MM-YYYY'), 
                TO_DATE('31-03-2026', 'DD-MM-YYYY'), 
                'Nisha Patel', 
                'Annual contract for supply of Dr. Reddy medications to Nova North');
                
    add_contract('Nova South', 'Abbott', 
                TO_DATE('01-01-2025', 'DD-MM-YYYY'), 
                TO_DATE('31-12-2025', 'DD-MM-YYYY'), 
                'Rahul Singh', 
                'Contract for supply of Abbott medications to Nova South for the year 2025');
                
    add_contract('Nova South', 'GSK', 
                TO_DATE('01-02-2025', 'DD-MM-YYYY'), 
                TO_DATE('31-01-2026', 'DD-MM-YYYY'), 
                'Deepak Verma', 
                'Contract for supply of GSK medications to Nova South from Feb 2025 to Jan 2026');

    -- Create prescriptions
    add_prescription('PRESC001', '123456789012', '987654321012', TO_DATE('10-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC002', '223456789012', '887654321012', TO_DATE('11-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC003', '323456789012', '787654321012', TO_DATE('12-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC004', '423456789012', '687654321012', TO_DATE('13-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC005', '523456789012', '587654321012', TO_DATE('14-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC006', '623456789012', '487654321012', TO_DATE('15-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC007', '723456789012', '387654321012', TO_DATE('16-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC008', '823456789012', '287654321012', TO_DATE('17-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC009', '123456789012', '187654321012', TO_DATE('18-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC010', '223456789012', '087654321012', TO_DATE('19-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC013', '223456789012', '887654321012', TO_DATE('21-04-2025', 'DD-MM-YYYY'));
    add_prescription('PRESC014', '223456789012', '987654321012', TO_DATE('22-04-2025', 'DD-MM-YYYY'));
    -- Add drugs to prescriptions
    add_drug_to_prescription('PRESC001', 'Sun Pharma', 'Paracetamol', 20);
    add_drug_to_prescription('PRESC001', 'Cipla', 'Azithromycin', 5);
    
    add_drug_to_prescription('PRESC002', 'Dr. Reddy', 'Metformin', 30);
    add_drug_to_prescription('PRESC002', 'Ranbaxy', 'Lisinopril', 10);
    
    add_drug_to_prescription('PRESC003', 'Sun Pharma', 'Amoxicillin', 15);
    add_drug_to_prescription('PRESC003', 'GSK', 'Augmentin', 7);
    
    add_drug_to_prescription('PRESC004', 'Pfizer', 'Lipitor', 30);
    add_drug_to_prescription('PRESC004', 'Dr. Reddy', 'Atorvastatin', 30);
    
    add_drug_to_prescription('PRESC005', 'Ranbaxy', 'Losartan', 30);
    add_drug_to_prescription('PRESC005', 'Cipla', 'Pantoprazole', 15);
    
    add_drug_to_prescription('PRESC006', 'Sun Pharma', 'Aspirin', 30);
    add_drug_to_prescription('PRESC006', 'Abbott', 'Brufen', 15);
    
    add_drug_to_prescription('PRESC007', 'Cipla', 'Montelukast', 30);
    add_drug_to_prescription('PRESC007', 'Sun Pharma', 'Cetirizine', 20);
    
    add_drug_to_prescription('PRESC008', 'Dr. Reddy', 'Glimepiride', 30);
    add_drug_to_prescription('PRESC008', 'Dr. Reddy', 'Ondansetron', 10);
    
    add_drug_to_prescription('PRESC009', 'Ranbaxy', 'Clopidogrel', 30);
    add_drug_to_prescription('PRESC009', 'Ranbaxy', 'Ramipril', 30);
    
    add_drug_to_prescription('PRESC010', 'Pfizer', 'Zoloft', 30);
    add_drug_to_prescription('PRESC010', 'Pfizer', 'Lyrica', 20);

    add_drug_to_prescription('PRESC014', 'Sun Pharma', 'Amoxicillin', 15);
    add_drug_to_prescription('PRESC014', 'GSK', 'Augmentin', 8);
    
    -- Update some contracts to test the update functionality
    update_contract_supervisor('Nova Central', 'Sun Pharma',TO_DATE('01-01-2025', 'DD-MM-YYYY'),TO_DATE('31-12-2025', 'DD-MM-YYYY'), 'Vikram Malhotra');
    update_contract_supervisor('Nova East', 'Ranbaxy',TO_DATE('01-03-2025', 'DD-MM-YYYY'),TO_DATE('28-02-2026', 'DD-MM-YYYY'),'Neha Singhania');
    
    -- Add additional prescriptions to test the latest date constraint
    -- These should replace the previous prescriptions from the same doctor to the same patient
    add_prescription('PRESC011', '123456789012', '987654321012', TO_DATE('20-04-2025', 'DD-MM-YYYY'));
    add_drug_to_prescription('PRESC011', 'Sun Pharma', 'Paracetamol', 30);
    add_drug_to_prescription('PRESC011', 'Sun Pharma', 'Aspirin', 15);
    
    -- add_prescription('PRESC012', '223456789012', '887654321012', TO_DATE('21-04-2025', 'DD-MM-YYYY'));
    -- add_drug_to_prescription('PRESC012', 'Dr. Reddy', 'Metformin', 45);
    -- add_drug_to_prescription('PRESC012', 'Cipla', 'Azithromycin', 7);
    
    DBMS_OUTPUT.PUT_LINE('Data insertion completed successfully.');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error during data insertion: ' || SQLERRM);
        ROLLBACK;
END;
/