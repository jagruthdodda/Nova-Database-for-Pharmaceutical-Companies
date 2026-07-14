from datetime import date
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, status

from ..db import pool
from ..models import PatientCreate, PatientUpdate

router = APIRouter(prefix="/patients", tags=["patients"])


@router.post("", status_code=status.HTTP_201_CREATED)
def create_patient(p: PatientCreate):
    with pool.connection() as conn:
        conn.execute(
            "CALL insert_patient(%s, %s, %s, %s, %s)",
            [p.aadhar_id, p.name, p.address, p.age, p.primary_doctor_id],
        )
    return {"message": "patient created", "aadhar_id": p.aadhar_id}


@router.put("/{patient_id}")
def update_patient(patient_id: str, body: PatientUpdate):
    with pool.connection() as conn:
        conn.execute("CALL update_patient_address(%s, %s)", [patient_id, body.address])
    return {"message": "patient updated", "aadhar_id": patient_id}


@router.delete("/{patient_id}")
def delete_patient(patient_id: str):
    with pool.connection() as conn:
        conn.execute("CALL delete_patient(%s)", [patient_id])
    return {"message": "patient deleted", "aadhar_id": patient_id}


# Reports #2 and #3: prescriptions for a patient.
#   ?date=YYYY-MM-DD          -> that exact day's prescription (report #3)
#   ?from=YYYY-MM-DD&to=...   -> everything in the period (report #2)
# Filters live in query params (REST convention), not the path.
@router.get("/{patient_id}/prescriptions")
def patient_prescriptions(
    patient_id: str,
    from_date: Optional[date] = Query(None, alias="from"),
    to_date: Optional[date] = Query(None, alias="to"),
    on_date: Optional[date] = Query(None, alias="date"),
):
    with pool.connection() as conn:
        if on_date is not None:
            cur = conn.execute(
                "SELECT * FROM get_prescription_by_date(%s, %s)", [patient_id, on_date]
            )
        elif from_date is not None and to_date is not None:
            cur = conn.execute(
                "SELECT * FROM get_prescriptions_in_period(%s, %s, %s)",
                [patient_id, from_date, to_date],
            )
        else:
            raise HTTPException(
                status_code=400,
                detail="Provide either ?date=YYYY-MM-DD or both ?from= and ?to=.",
            )
        return cur.fetchall()
