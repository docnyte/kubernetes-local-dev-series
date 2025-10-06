"""Tests for users endpoints."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


@pytest.mark.asyncio
async def test_get_users_success():
    """Test getting all users successfully."""
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = [
        {"id": 1, "name": "John Doe", "email": "john@example.com"},
        {"id": 2, "name": "Jane Smith", "email": "jane@example.com"},
    ]
    mock_response.raise_for_status = MagicMock()

    mock_client = AsyncMock()
    mock_client.__aenter__.return_value.get = AsyncMock(return_value=mock_response)

    with patch("httpx.AsyncClient", return_value=mock_client):
        response = client.get("/api/users")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        assert data[0]["name"] == "John Doe"
        assert data[1]["name"] == "Jane Smith"


@pytest.mark.asyncio
async def test_get_users_empty_list():
    """Test getting users when list is empty."""
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = []
    mock_response.raise_for_status = MagicMock()

    mock_client = AsyncMock()
    mock_client.__aenter__.return_value.get = AsyncMock(return_value=mock_response)

    with patch("httpx.AsyncClient", return_value=mock_client):
        response = client.get("/api/users")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 0


@pytest.mark.asyncio
async def test_get_users_service_unavailable():
    """Test getting users when data service is unavailable."""
    with patch(
        "httpx.AsyncClient.get",
        side_effect=Exception("Connection refused"),
    ):
        response = client.get("/api/users")
        assert response.status_code == 500
        data = response.json()
        assert "detail" in data


@pytest.mark.asyncio
async def test_get_user_by_id_success():
    """Test getting a specific user by ID."""
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com",
    }
    mock_response.raise_for_status = MagicMock()

    mock_client = AsyncMock()
    mock_client.__aenter__.return_value.get = AsyncMock(return_value=mock_response)

    with patch("httpx.AsyncClient", return_value=mock_client):
        response = client.get("/api/users/1")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == 1
        assert data["name"] == "John Doe"
        assert data["email"] == "john@example.com"


@pytest.mark.asyncio
async def test_get_user_by_id_not_found():
    """Test getting a user that doesn't exist."""
    mock_response = AsyncMock()
    mock_response.status_code = 404
    mock_response.text = "User not found"

    mock_get = AsyncMock(return_value=mock_response)
    mock_get.side_effect = Exception("Not Found")
    mock_response.raise_for_status.side_effect = Exception("Not Found")

    with patch("httpx.AsyncClient.get", return_value=mock_response):
        mock_response.raise_for_status.side_effect = Exception("404")
        response = client.get("/api/users/999")
        assert response.status_code in [404, 500]


@pytest.mark.asyncio
async def test_get_user_service_unavailable():
    """Test getting a user when data service is unavailable."""
    with patch(
        "httpx.AsyncClient.get",
        side_effect=Exception("Connection refused"),
    ):
        response = client.get("/api/users/1")
        assert response.status_code == 500
        data = response.json()
        assert "detail" in data
