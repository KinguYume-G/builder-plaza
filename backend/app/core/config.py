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
    github_redirect_uri: str = "http://localhost:8000/auth/github/callback"

    # Post-login target: the callback 302s the browser here with the JWT.
    frontend_url: str = "http://localhost:3000"

    linkedin_client_id: str = ""
    linkedin_client_secret: str = ""
    linkedin_redirect_uri: str = "http://localhost:8000/auth/linkedin/callback"
    linkedin_mode: str = "simulated"  # "simulated" | "live" -- see ADR-0003

    aws_region: str = "ap-southeast-1"
    s3_bucket_name: str = ""
    # Explicit creds for the builderplaza account that OWNS the bucket. We build
    # the boto3 client from these rather than the machine's default AWS profile,
    # which belongs to a different account that can't see the bucket.
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    bedrock_model_id: str = "anthropic.claude-3-haiku-20240307-v1:0"


settings = Settings()
