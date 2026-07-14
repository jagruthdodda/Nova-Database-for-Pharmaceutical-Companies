from fastapi import APIRouter, status

from ..db import pool
from ..models import CompanyCreate, CompanyUpdate

router = APIRouter(prefix="/companies", tags=["companies"])


@router.post("", status_code=status.HTTP_201_CREATED)
def create_company(c: CompanyCreate):
    with pool.connection() as conn:
        conn.execute("CALL insert_company(%s, %s)", [c.name, c.phone])
    return {"message": "company created", "name": c.name}


@router.put("/{name}")
def update_company(name: str, body: CompanyUpdate):
    with pool.connection() as conn:
        conn.execute("CALL update_company_phone(%s, %s)", [name, body.phone])
    return {"message": "company updated", "name": name}


@router.delete("/{name}")
def delete_company(name: str):
    with pool.connection() as conn:
        conn.execute("CALL delete_company(%s)", [name])
    return {"message": "company deleted", "name": name}


# Report #4: drugs produced by this company.
@router.get("/{name}/drugs")
def company_drugs(name: str):
    with pool.connection() as conn:
        cur = conn.execute("SELECT * FROM get_drugs_by_company(%s)", [name])
        return cur.fetchall()
