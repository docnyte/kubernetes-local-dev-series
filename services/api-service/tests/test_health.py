"""Tests for health check endpoint."""

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_check_success():
    """Test health check endpoint returns 200."""
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "API Service"
    assert data["version"] == "0.1.0"
    assert "data_service_status" in data


@pytest.mark.asyncio
async def test_health_check_data_service_connected():
    """Test health check when data service is connected."""
    mock_response = AsyncMock()
    mock_response.status_code = 200

    with patch("httpx.AsyncClient.get", return_value=mock_response):
        response = client.get("/api/health")
        assert response.status_code == 200
        data = response.json()
        assert data["data_service_status"] == "connected"


@pytest.mark.asyncio
async def test_health_check_data_service_unreachable():
    """Test health check when data service is unreachable."""
    with patch("httpx.AsyncClient.get", side_effect=Exception("Connection refused")):
        response = client.get("/api/health")
        assert response.status_code == 200
        data = response.json()
        assert (
            "error" in data["data_service_status"] or "unreachable" in data["data_service_status"]
        )


def test_root_endpoint():
    """Test root endpoint returns welcome message."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "docs" in data
    assert "health" in data
