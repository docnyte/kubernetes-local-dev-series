"""Pydantic models for API request/response validation."""

from pydantic import BaseModel, Field


class User(BaseModel):
    """User model returned by the API."""

    id: int = Field(..., description="Unique user identifier")
    name: str = Field(..., min_length=1, max_length=100, description="User's full name")
    email: str = Field(..., description="User's email address")

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "id": 1,
                    "name": "John Doe",
                    "email": "john.doe@example.com",
                }
            ]
        }
    }


class HealthResponse(BaseModel):
    """Health check response model."""

    status: str = Field(..., description="Service health status")
    service: str = Field(..., description="Service name")
    version: str = Field(..., description="Service version")
    data_service_status: str | None = Field(None, description="Data service connectivity status")

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "status": "healthy",
                    "service": "API Service",
                    "version": "0.1.0",
                    "data_service_status": "connected",
                }
            ]
        }
    }


class ErrorResponse(BaseModel):
    """Standard error response model."""

    detail: str = Field(..., description="Error message")
    status_code: int = Field(..., description="HTTP status code")

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "detail": "User not found",
                    "status_code": 404,
                }
            ]
        }
    }
