from fastapi import APIRouter, status

from ..db import pool
from ..models import DoctorCreate, DoctorUpdate

router = APIRouter(prefix="/doctors", tags=["doctors"])


@router.post("", status_code=status.HTTP_201_CREATED)
def create_doctor(doctor: DoctorCreate):
    with pool.connection() as conn:
        conn.execute(
            "CALL insert_doctor(%s, %s, %s, %s)",
            [doctor.aadhar_id, doctor.name, doctor.specialty, doctor.years_experience],
        )
    return {"message": "doctor created", "aadhar_id": doctor.aadhar_id}


@router.put("/{doctor_id}")
def update_doctor(doctor_id: str, body: DoctorUpdate):
    with pool.connection() as conn:
        conn.execute("CALL update_doctor(%s, %s)", [doctor_id, body.years_experience])
    return {"message": "doctor updated", "aadhar_id": doctor_id}


@router.delete("/{doctor_id}")
def delete_doctor(doctor_id: str):
    with pool.connection() as conn:
        conn.execute("CALL delete_doctor(%s)", [doctor_id])
    return {"message": "doctor deleted", "aadhar_id": doctor_id}


# Report #7: the doctor's patients.
@router.get("/{doctor_id}/patients")
def list_doctor_patients(doctor_id: str):
    with pool.connection() as conn:
        cur = conn.execute("SELECT * FROM get_patients_by_doctor(%s)", [doctor_id])
        return cur.fetchall()
