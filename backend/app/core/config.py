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

    # Optional PAT for server-side GitHub reads. Unauthenticated the public API
    # allows 60 req/hr/IP, which F1/F4/F5/F6/F10 exhaust quickly; a token lifts
    # this to 5000/hr. Public data only -- the token grants no extra scopes.
    github_token: str = ""

    github_client_id: str = ""
    github_client_secret: str = ""
    github_redirect_uri: str = "http://localhost:8000/auth/github/callback"

    # Post-login target: the callback 302s the browser here with the JWT.
    frontend_url: str = "http://localhost:3000"

    linkedin_client_id: str = ""
    linkedin_client_secret: str = ""
    linkedin_redirect_uri: str = "http://localhost:8000/auth/linkedin/callback"
    linkedin_mode: str = "simulated"  # "simulated" | "live" -- see ADR-0003

    # F6 Trust Score component weights (renormalised over the components that
    # are actually available for a given user, so a missing source -- e.g. no
    # LinkedIn tenure on the live OIDC path -- never zeroes the score).
    trust_weight_github: float = 0.45
    trust_weight_linkedin: float = 0.20
    trust_weight_peer: float = 0.25
    trust_weight_payment: float = 0.10

    aws_region: str = "ap-southeast-1"
    s3_bucket_name: str = ""
    # Explicit creds for the builderplaza account that OWNS the bucket. We build
    # the boto3 client from these rather than the machine's default AWS profile,
    # which belongs to a different account that can't see the bucket.
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    bedrock_model_id: str = "anthropic.claude-3-haiku-20240307-v1:0"


settings = Settings()
