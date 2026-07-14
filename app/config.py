from pydantic_settings import BaseSettings, SettingsConfigDict


# Same BaseSettings pattern your course used. Reads from .env (case-insensitive:
# DB_PASSWORD -> db_password). db_password has no default, so the app refuses to
# start if it's missing — fail fast instead of silently connecting wrong.
class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "nova"
    db_user: str = "postgres"
    db_password: str


settings = Settings()
