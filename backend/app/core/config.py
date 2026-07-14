from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=("../.env", ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    environment: str = "local"

    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/builder_plaza"

    jwt_secret: str = "change-me"

    github_client_id: str = ""
    github_client_secret: str = ""

    linkedin_client_id: str = ""
    linkedin_client_secret: str = ""
    linkedin_mode: str = "simulated"  # "simulated" | "live" -- see ADR-0003

    aws_region: str = "ap-southeast-1"
    s3_bucket_name: str = ""
    bedrock_model_id: str = "anthropic.claude-3-haiku-20240307-v1:0"


settings = Settings()
