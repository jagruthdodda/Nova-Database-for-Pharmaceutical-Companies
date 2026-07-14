from fastapi import APIRouter, status

from ..db import pool
from ..models import PharmacyCreate, PharmacyUpdate, SellCreate, SellUpdate

router = APIRouter(prefix="/pharmacies", tags=["pharmacies"])


@router.post("", status_code=status.HTTP_201_CREATED)
def create_pharmacy(p: PharmacyCreate):
    with pool.connection() as conn:
        conn.execute("CALL insert_pharmacy(%s, %s, %s)", [p.name, p.address, p.phone])
    return {"message": "pharmacy created", "name": p.name}


@router.put("/{name}")
def update_pharmacy(name: str, body: PharmacyUpdate):
    with pool.connection() as conn:
        conn.execute("CALL update_pharmacy_phone(%s, %s)", [name, body.phone])
    return {"message": "pharmacy updated", "name": name}


@router.delete("/{name}")
def delete_pharmacy(name: str):
    with pool.connection() as conn:
        conn.execute("CALL delete_pharmacy(%s)", [name])
    return {"message": "pharmacy deleted", "name": name}


# Report #5: stock/price list of this pharmacy.
@router.get("/{name}/stock")
def pharmacy_stock(name: str):
    with pool.connection() as conn:
        cur = conn.execute("SELECT * FROM get_pharmacy_stock(%s)", [name])
        return cur.fetchall()


# Report #6: contact details of companies this pharmacy has contracts with.
@router.get("/{name}/companies")
def pharmacy_companies(name: str):
    with pool.connection() as conn:
        cur = conn.execute("SELECT * FROM get_pharmacy_company_contact(%s)", [name])
        return cur.fetchall()


# --- sells sub-resource: the drugs this pharmacy sells (with per-pharmacy price) ---
@router.post("/{name}/drugs", status_code=status.HTTP_201_CREATED)
def add_pharmacy_drug(name: str, body: SellCreate):
    with pool.connection() as conn:
        conn.execute("CALL insert_sells(%s, %s, %s)", [name, body.drug_id, body.price])
    return {"message": "drug added to pharmacy", "pharmacy": name, "drug_id": body.drug_id}


@router.put("/{name}/drugs/{drug_id}")
def update_pharmacy_drug_price(name: str, drug_id: int, body: SellUpdate):
    with pool.connection() as conn:
        conn.execute("CALL update_sells_price(%s, %s, %s)", [name, drug_id, body.price])
    return {"message": "price updated", "pharmacy": name, "drug_id": drug_id}


@router.delete("/{name}/drugs/{drug_id}")
def remove_pharmacy_drug(name: str, drug_id: int):
    with pool.connection() as conn:
        conn.execute("CALL delete_sells(%s, %s)", [name, drug_id])
    return {"message": "drug removed from pharmacy", "pharmacy": name, "drug_id": drug_id}
