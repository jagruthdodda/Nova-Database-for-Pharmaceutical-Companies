from psycopg_pool import ConnectionPool
from psycopg.rows import dict_row

from .config import settings

# NEW vs your course (which used psycopg2 conn-per-request, then SQLAlchemy):
#   * ConnectionPool  -> one pool of reused connections instead of connecting per request.
#   * row_factory=dict_row -> cursors return dicts ({"name": ...}) not tuples.
#   * open=False -> build the pool object now, actually connect at app startup
#                   (done in main.py's lifespan), so import never blocks on the DB.
conninfo = (
    f"host={settings.db_host} port={settings.db_port} "
    f"dbname={settings.db_name} user={settings.db_user} "
    f"password={settings.db_password}"
)

pool = ConnectionPool(
    conninfo,
    min_size=1,
    max_size=10,
    open=False,
    kwargs={"row_factory": dict_row},
)
