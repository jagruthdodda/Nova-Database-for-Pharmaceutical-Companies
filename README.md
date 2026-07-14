# NOVA — Pharmacy Chain Database & API

A relational database and REST API for **NOVA**, a chain of pharmacies that sells
drugs supplied by pharmaceutical companies. Models pharmacies, companies, drugs,
patients, doctors, prescriptions, and supply contracts, and exposes CRUD plus a
set of reports.

Built on **PostgreSQL** with business logic in **PL/pgSQL** (stored procedures
and functions), fronted by a **FastAPI** service that talks to the database with
**psycopg 3** — no ORM.

## Stack & why

| Layer | Choice | Why |
|---|---|---|
| Database | PostgreSQL 18 | Robust relational engine; strong constraint + PL/pgSQL support |
| DB logic | PL/pgSQL procedures & functions | Writes = `CALL` procedures, reads = `SELECT` functions; keeps logic in the DB |
| Driver | psycopg 3 (`psycopg[binary]`) + `psycopg_pool` | Modern driver; explicit connection pool for safe concurrency |
| API | FastAPI + Pydantic | Typed request validation, auto-generated OpenAPI docs |
| Config | pydantic-settings + `.env` | Secrets out of code and git |

**No ORM** on purpose: the schema is stored-procedure–backed, so the API is a
thin, parameterized layer that calls those procedures/functions directly. This
keeps the SQL visible and the database as the source of truth.

## Architecture

```
HTTP request
   -> routers/*.py     FastAPI endpoints: validate (Pydantic) + inline parameterized SQL
      -> db.py         psycopg3 connection pool (opened at startup via lifespan)
         -> PostgreSQL PL/pgSQL procedures (writes) & functions (reads)
```

- `app/main.py` — app, lifespan (opens/closes the pool), router registration.
- `app/config.py` — settings from `.env`.
- `app/db.py` — the connection pool (`dict_row` so rows come back as dicts).
- `app/models.py` — Pydantic request models (validation).
- `app/errors.py` — maps DB constraint errors to HTTP codes (409/400).
- `app/routers/` — one module per resource.

## Schema highlights

- **Composite natural keys → surrogate keys.** `drug`, `contract`, and
  `prescription` each use a surrogate `*_id` for a clean API surface, with a
  `UNIQUE` constraint preserving the original natural-key business rule.
- **Prescriptions are history-preserving.** A prescription is a header
  (`prescription`) plus drug lines (`prescription_drug`). `UNIQUE (patient_id,
  doctor_id, prescription_date)` enforces "one prescription per doctor-patient
  per day" while keeping full history (the spec's "latest only" is a documented,
  one-line alternative).
- **Constraints enforced in the DB:** `NOT NULL`, `CHECK` (age, price, quantity,
  date order), and foreign keys with deliberate `ON DELETE` behavior (e.g.
  deleting a company cascades to its drugs).

## Setup

Requires Python 3.11+ and a running PostgreSQL 18 instance.

```bash
# 1. Create the database and load schema + seed data (psql or pgAdmin)
createdb nova
psql -d nova -f postgres_schema.sql
psql -d nova -f seed.sql

# 2. Python environment
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt        # Windows
# source .venv/bin/activate && pip install -r requirements.txt  # macOS/Linux

# 3. Configure DB access — create a .env file in the project root:
#   DB_HOST=localhost
#   DB_PORT=5432
#   DB_NAME=nova
#   DB_USER=postgres
#   DB_PASSWORD=your_password

# 4. Run
.venv\Scripts\python -m uvicorn app.main:app --reload
```

Then open **http://127.0.0.1:8000/docs** for the interactive API.

## API overview

CRUD for every entity, plus the reports the spec requires.

| Resource | Endpoints |
|---|---|
| doctors | `POST /doctors`, `PUT /doctors/{id}`, `DELETE /doctors/{id}`, `GET /doctors/{id}/patients` |
| patients | `POST /patients`, `PUT /patients/{id}`, `DELETE /patients/{id}`, `GET /patients/{id}/prescriptions?from=&to=` / `?date=` |
| companies | `POST /companies`, `PUT /companies/{name}`, `DELETE /companies/{name}`, `GET /companies/{name}/drugs` |
| drugs | `POST /drugs`, `PUT /drugs/{id}`, `DELETE /drugs/{id}` |
| pharmacies | `POST /pharmacies`, `PUT /pharmacies/{name}`, `DELETE /pharmacies/{name}`, `GET /pharmacies/{name}/stock`, `GET /pharmacies/{name}/companies`, and `.../drugs` sub-resource (sells) |
| contracts | `POST /contracts`, `PUT /contracts/{id}`, `DELETE /contracts/{id}` |
| prescriptions | `POST /prescriptions/lines`, `PUT /prescriptions/{id}/drugs/{drug_id}`, `DELETE /prescriptions/{id}` and `.../drugs/{drug_id}` |

### Reports (from the spec)

| # | Report | Endpoint |
|---|---|---|
| 2 | Prescriptions of a patient in a period | `GET /patients/{id}/prescriptions?from=&to=` |
| 3 | A patient's prescription on a date | `GET /patients/{id}/prescriptions?date=` |
| 4 | Drugs produced by a company | `GET /companies/{name}/drugs` |
| 5 | Stock position of a pharmacy | `GET /pharmacies/{name}/stock` |
| 6 | A pharmacy's company contacts | `GET /pharmacies/{name}/companies` |
| 7 | Patients of a doctor | `GET /doctors/{id}/patients` |

## Files

- `postgres_schema.sql` — tables, constraints, procedures, functions.
- `seed.sql` — meaningful sample data (re-runnable).
- `mysql_schema.sql` — the original MySQL version this was ported from.
- `app/` — the FastAPI service.
