from fastapi import APIRouter, status

from ..db import pool
from ..models import ContractCreate, ContractSupervisorUpdate

router = APIRouter(prefix="/contracts", tags=["contracts"])


@router.post("", status_code=status.HTTP_201_CREATED)
def create_contract(c: ContractCreate):
    with pool.connection() as conn:
        conn.execute(
            "CALL insert_contract(%s, %s, %s, %s, %s, %s)",
            [c.pharmacy_name, c.company_name, c.start_date, c.end_date, c.content, c.supervisor],
        )
        # contract_id is auto-generated; read it back (same transaction) so the
        # client can address the contract afterwards.
        cur = conn.execute(
            "SELECT contract_id FROM contract "
            "WHERE pharmacy_name = %s AND company_name = %s AND start_date = %s",
            [c.pharmacy_name, c.company_name, c.start_date],
        )
        row = cur.fetchone()
    return {"message": "contract created", "contract_id": row["contract_id"]}


# Only the supervisor is mutable (per the spec); contract_id identifies the row.
@router.put("/{contract_id}")
def update_contract_supervisor(contract_id: int, body: ContractSupervisorUpdate):
    with pool.connection() as conn:
        conn.execute(
            "CALL update_contract_supervisor(%s, %s)", [contract_id, body.supervisor]
        )
    return {"message": "supervisor updated", "contract_id": contract_id}


@router.delete("/{contract_id}")
def delete_contract(contract_id: int):
    with pool.connection() as conn:
        conn.execute("CALL delete_contract(%s)", [contract_id])
    return {"message": "contract deleted", "contract_id": contract_id}
