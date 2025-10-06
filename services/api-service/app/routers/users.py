"""Users endpoint for the API service."""

import httpx
from fastapi import APIRouter, HTTPException, status

from app.config import settings
from app.models import ErrorResponse, User

router = APIRouter(prefix="/api", tags=["users"])


@router.get(
    "/users",
    response_model=list[User],
    status_code=status.HTTP_200_OK,
    summary="Get all users",
    description="Retrieves all users from the data service",
    responses={
        503: {
            "model": ErrorResponse,
            "description": "Data service unavailable",
        }
    },
)
async def get_users() -> list[User]:
    """
    Fetch all users from the data service.

    Returns:
        list[User]: List of all users

    Raises:
        HTTPException: If the data service is unavailable or returns an error
    """
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{settings.data_service_url}/data/users")
            response.raise_for_status()
            users_data = response.json()
            return [User(**user) for user in users_data]
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=e.response.status_code,
            detail=f"Data service error: {e.response.text}",
        ) from e
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Data service unavailable: {type(e).__name__}",
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal error: {str(e)}",
        ) from e


@router.get(
    "/users/{user_id}",
    response_model=User,
    status_code=status.HTTP_200_OK,
    summary="Get user by ID",
    description="Retrieves a specific user by ID from the data service",
    responses={
        404: {
            "model": ErrorResponse,
            "description": "User not found",
        },
        503: {
            "model": ErrorResponse,
            "description": "Data service unavailable",
        },
    },
)
async def get_user(user_id: int) -> User:
    """
    Fetch a specific user by ID from the data service.

    Args:
        user_id: The unique identifier of the user

    Returns:
        User: The requested user

    Raises:
        HTTPException: If the user is not found or data service is unavailable
    """
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{settings.data_service_url}/data/users/{user_id}")
            response.raise_for_status()
            user_data = response.json()
            return User(**user_data)
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User with ID {user_id} not found",
            ) from e
        raise HTTPException(
            status_code=e.response.status_code,
            detail=f"Data service error: {e.response.text}",
        ) from e
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Data service unavailable: {type(e).__name__}",
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal error: {str(e)}",
        ) from e
