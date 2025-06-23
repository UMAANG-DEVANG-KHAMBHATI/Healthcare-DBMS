## Database Design for a Healthcare System

This project features a **normalized and relationally sound database system** designed for **NOVA**, a fictional pharmaceutical retail chain. The goal was to model, implement, and manage the core business operations of pharmacies, drug manufacturers, patients, doctors, and prescriptions using **Oracle SQL and PL/SQL**.

### 🔧 Design Highlights

- ✅ Designed in **Third Normal Form (3NF)** to eliminate redundancy and ensure referential integrity.
- 🔗 Built with **11 interconnected relations** capturing key business entities and interactions:
  - `PHARMACY`, `DOCTOR`, `PATIENT`, `DRUG`, `PHARMACEUTICAL_COMPANY`
  - `PRESCRIPTION`, `PRESC_DETAILS`, `SELLS`, `CONTRACTS`, `TREATED_BY`
- ⚙️ Optimized over **20+ stored operations** using:
  - `PL/SQL Procedures`
  - `Functions`
  - `Cursors`
  - `Triggers`
- 📊 Designed to scale and query over **500+ rows** of realistic sample data (dummy dataset provided).

---

### 🗺️ Schema Snapshots

### ER Diagram  
![ER Diagram](ER%20Diagram%20%26%20Mapping/er-diagram.png)

### Relational Mapping  
![Relational Mapping](ER%20Diagram%20%26%20Mapping/relational-mapping.png)


---

### Key Functionalities Supported
- Add, update, and delete: **Doctors**, **Patients**, **Drugs**, **Prescriptions**, **Contracts**
- Generate:
  - Prescription reports by patient and date
  - Drug inventory per pharmacy
  - Contract details between pharmacy & pharma companies
  - Patient list for a given doctor
- Validate:
  - One prescription per patient per date
  - Unique `PrescID`, consistent foreign keys, and quantity constraints
- Enforced through:
  - **Primary / Foreign Keys**
  - **CHECK / UNIQUE constraints**
  - **Triggers** for critical business rules

---

> 💡 *The system was designed with command-line demonstration in mind and does not rely on a graphical interface, ensuring full SQL/PLSQL interaction fidelity.*


