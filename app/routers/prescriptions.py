from fastapi import APIRouter, status

from ..db import pool
from ..models import PrescriptionLineCreate, PrescriptionLineUpdate

router = APIRouter(prefix="/prescriptions", tags=["prescriptions"])


# Add one drug line. The procedure creates the slip for that
# (patient, doctor, date) on first use and appends to it thereafter — so you
# build a multi-drug prescription by POSTing several lines with the same
# patient/doctor/date.
@router.post("/lines", status_code=status.HTTP_201_CREATED)
def add_prescription_line(line: PrescriptionLineCreate):
    with pool.connection() as conn:
        conn.execute(
            "CALL add_prescription_drug(%s, %s, %s, %s, %s)",
            [line.patient_id, line.doctor_id, line.prescription_date, line.drug_id, line.quantity],
        )
    return {"message": "prescription line added"}


@router.put("/{prescription_id}/drugs/{drug_id}")
def update_line_quantity(prescription_id: int, drug_id: int, body: PrescriptionLineUpdate):
    with pool.connection() as conn:
        conn.execute(
            "CALL update_prescription_qty(%s, %s, %s)",
            [prescription_id, drug_id, body.quantity],
        )
    return {"message": "quantity updated", "prescription_id": prescription_id, "drug_id": drug_id}


@router.delete("/{prescription_id}/drugs/{drug_id}")
def delete_line(prescription_id: int, drug_id: int):
    with pool.connection() as conn:
        conn.execute("CALL delete_prescription_drug(%s, %s)", [prescription_id, drug_id])
    return {"message": "prescription line deleted"}


@router.delete("/{prescription_id}")
def delete_prescription(prescription_id: int):
    with pool.connection() as conn:
        conn.execute("CALL delete_prescription(%s)", [prescription_id])
    return {"message": "prescription deleted"}
