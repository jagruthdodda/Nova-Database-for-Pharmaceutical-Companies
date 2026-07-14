from contextlib import asynccontextmanager

from fastapi import FastAPI

from .db import pool
from .errors import register_error_handlers
from .routers import (
    companies,
    contracts,
    doctors,
    drugs,
    patients,
    pharmacies,
    prescriptions,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    pool.open()
    yield
    pool.close()


app = FastAPI(title="NOVA Pharmacy API", lifespan=lifespan)

# Map DB constraint errors -> clean HTTP codes for every endpoint.
register_error_handlers(app)

# Register each resource's routes.
for module in (doctors, patients, companies, pharmacies, drugs, contracts, prescriptions):
    app.include_router(module.router)


@app.get("/")
def root():
    return {"message": "NOVA Pharmacy API is running"}


@app.get("/health")
def health():
    with pool.connection() as conn:
        row = conn.execute("SELECT 1 AS ok").fetchone()
    return {"database": "up", "result": row["ok"]}
