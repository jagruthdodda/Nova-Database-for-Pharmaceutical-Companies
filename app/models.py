from datetime import date

from pydantic import BaseModel, Field

# Pydantic request models = shape + validation of incoming JSON. Invalid input is
# rejected with 422 BEFORE any DB call. Field rules mirror the table constraints
# so we fail early with a clear message. "*Create" = full row; "*Update" = only
# the field(s) the matching stored procedure actually changes.


# ---- doctor ----------------------------------------------------------------
class DoctorCreate(BaseModel):
    aadhar_id: str = Field(min_length=12, max_length=12)
    name: str = Field(min_length=1)
    specialty: str = Field(min_length=1)
    years_experience: int = Field(ge=0)


class DoctorUpdate(BaseModel):
    years_experience: int = Field(ge=0)


# ---- patient ---------------------------------------------------------------
class PatientCreate(BaseModel):
    aadhar_id: str = Field(min_length=12, max_length=12)
    name: str = Field(min_length=1)
    address: str = Field(min_length=1)
    age: int = Field(gt=0, lt=150)
    primary_doctor_id: str = Field(min_length=12, max_length=12)


class PatientUpdate(BaseModel):
    address: str = Field(min_length=1)


# ---- pharmaceutical company ------------------------------------------------
class CompanyCreate(BaseModel):
    name: str = Field(min_length=1)
    phone: str = Field(min_length=1, max_length=15)


class CompanyUpdate(BaseModel):
    phone: str = Field(min_length=1, max_length=15)


# ---- drug ------------------------------------------------------------------
class DrugCreate(BaseModel):
    trade_name: str = Field(min_length=1)
    formula: str = Field(min_length=1)
    company_name: str = Field(min_length=1)


class DrugUpdate(BaseModel):
    formula: str = Field(min_length=1)


# ---- pharmacy --------------------------------------------------------------
class PharmacyCreate(BaseModel):
    name: str = Field(min_length=1)
    address: str = Field(min_length=1)
    phone: str = Field(min_length=1, max_length=15)


class PharmacyUpdate(BaseModel):
    phone: str = Field(min_length=1, max_length=15)


# ---- sells (a pharmacy sells a drug at a price) ----------------------------
class SellCreate(BaseModel):
    drug_id: int
    price: float = Field(ge=0)


class SellUpdate(BaseModel):
    price: float = Field(ge=0)


# ---- contract --------------------------------------------------------------
class ContractCreate(BaseModel):
    pharmacy_name: str = Field(min_length=1)
    company_name: str = Field(min_length=1)
    start_date: date
    end_date: date
    content: str = Field(min_length=1)
    supervisor: str = Field(min_length=1)


class ContractSupervisorUpdate(BaseModel):
    supervisor: str = Field(min_length=1)  # contract_id comes from the URL path


# ---- prescription line -----------------------------------------------------
class PrescriptionLineCreate(BaseModel):
    patient_id: str = Field(min_length=12, max_length=12)
    doctor_id: str = Field(min_length=12, max_length=12)
    prescription_date: date
    drug_id: int
    quantity: int = Field(gt=0)


class PrescriptionLineUpdate(BaseModel):
    quantity: int = Field(gt=0)
