"""Health check endpoint for the API service."""

import httpx
from fastapi import APIRouter, status

from app.config import settings
from app.models import HealthResponse

router = APIRouter(prefix="/api", tags=["health"])


@router.get(
    "/health",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Health check endpoint",
    description="Returns the health status of the API service and data service connectivity",
)
async def health_check() -> HealthResponse:
    """
    Check the health of the API service and verify connectivity to the data service.

    Returns:
        HealthResponse: Health status information including data service connectivity
    """
    data_service_status = "unknown"

    # Try to check data service connectivity
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            response = await client.get(f"{settings.data_service_url}/actuator/health")
            if response.status_code == 200:
                data_service_status = "connected"
            else:
                data_service_status = f"unhealthy (status: {response.status_code})"
    except httpx.RequestError as e:
        data_service_status = f"unreachable ({type(e).__name__})"
    except Exception as e:
        data_service_status = f"error ({type(e).__name__})"

    return HealthResponse(
        status="healthy",
        service=settings.app_name,
        version=settings.app_version,
        data_service_status=data_service_status,
    )
