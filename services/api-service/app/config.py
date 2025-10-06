"""Configuration management for the API service."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Service configuration
    data_service_url: str = "http://data-service:8080"
    port: int = 8000
    log_level: str = "INFO"

    # API metadata
    app_name: str = "API Service"
    app_version: str = "0.1.0"
    description: str = "Python FastAPI service for Kubernetes local development"


# Global settings instance
settings = Settings()
