from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from psycopg import errors


# One central place that turns raw Postgres constraint errors into clean HTTP
# responses. Registered on the app, so ANY endpoint that trips a constraint gets
# a proper status code + message instead of a 500 stack trace. This is why the
# routers themselves need no try/except.
def register_error_handlers(app: FastAPI) -> None:

    # Duplicate primary key / unique value -> 409 Conflict.
    @app.exception_handler(errors.UniqueViolation)
    async def _unique(request: Request, exc: errors.UniqueViolation):
        return JSONResponse(
            status_code=409,
            content={"detail": "Already exists (unique or primary-key conflict)."},
        )

    # Referencing a row that doesn't exist, or deleting one still referenced -> 409.
    @app.exception_handler(errors.ForeignKeyViolation)
    async def _fk(request: Request, exc: errors.ForeignKeyViolation):
        return JSONResponse(
            status_code=409,
            content={"detail": "Referenced record is missing, or is still in use elsewhere."},
        )

    # CHECK constraint (e.g. negative age/price/quantity) -> 400 Bad Request.
    @app.exception_handler(errors.CheckViolation)
    async def _check(request: Request, exc: errors.CheckViolation):
        return JSONResponse(
            status_code=400,
            content={"detail": "A value violates a check constraint (e.g. negative age, price, or quantity)."},
        )

    # Missing required column -> 400.
    @app.exception_handler(errors.NotNullViolation)
    async def _notnull(request: Request, exc: errors.NotNullViolation):
        return JSONResponse(
            status_code=400,
            content={"detail": "A required field is missing."},
        )

    # RAISE EXCEPTION from our PL/pgSQL (e.g. add_prescription_drug rules) -> 400,
    # surfacing the procedure's own message.
    @app.exception_handler(errors.RaiseException)
    async def _raise(request: Request, exc: errors.RaiseException):
        msg = exc.diag.message_primary if exc.diag and exc.diag.message_primary else str(exc)
        return JSONResponse(status_code=400, content={"detail": msg})
