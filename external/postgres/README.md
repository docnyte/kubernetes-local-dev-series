# PostgreSQL External Database

This directory contains the configuration for running PostgreSQL as an external Docker container, **outside** the Kubernetes cluster. This setup demonstrates how Kubernetes pods can connect to external databases using cross-network communication.

## Overview

- **Image**: PostgreSQL 17 (official image)
- **Database**: `devdb` (empty database, schema managed by Spring Boot)
- **Network**: `k8s-network` (custom bridge network)
- **Port**: 5432 (exposed to host)
- **Data Persistence**: None (ephemeral data for dev/testing)

## Architecture

```
Kubernetes Pods → host.docker.internal:5432 → PostgreSQL Container
                  (or tool-specific DNS)
```

The PostgreSQL container runs in the same Docker network as the Kubernetes nodes, allowing pods to connect via:
- `host.docker.internal` (k3d, kind)
- `host.k3d.internal` (k3d-specific)
- Host IP address (Minikube with specific configuration)

## Prerequisites

- Docker and Docker Compose installed
- No existing PostgreSQL container running on port 5432

## Quick Start

### 1. Start PostgreSQL Container

```bash
cd external/postgres
docker-compose up -d
```

### 2. Verify Container is Running

```bash
docker ps | grep postgres-devdb
```

Expected output:
```
CONTAINER ID   IMAGE         PORTS                    STATUS
abc123...      postgres:17   0.0.0.0:5432->5432/tcp   Up 10 seconds (healthy)
```

### 3. Check Container Health

```bash
docker-compose ps
```

The `STATE` column should show `Up` and `healthy` after ~10 seconds.

### 4. View Container Logs

```bash
docker-compose logs -f postgres
```

Look for:
```
PostgreSQL init process complete; ready for start up.
database system is ready to accept connections
```

### 5. Stop PostgreSQL Container

```bash
docker-compose down
```

## Connecting from Host

### Using psql

```bash
psql -h localhost -p 5432 -U postgres -d devdb
```

Password: `postgres`

### Using Connection String

```
postgresql://postgres:postgres@localhost:5432/devdb
```

### Verify Database

```bash
docker exec -it postgres-devdb psql -U postgres -d devdb -c "\l"
```

## Connecting from Kubernetes Pods

The Spring Boot Data Service connects using the following environment variables (configured in Kubernetes manifests):

```yaml
env:
  - name: DB_HOST
    value: "host.docker.internal"  # or host.k3d.internal for k3d
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: "devdb"
  - name: DB_USERNAME
    value: "postgres"
  - name: DB_PASSWORD
    value: "postgres"
```

The Spring Boot application constructs the JDBC URL:
```
jdbc:postgresql://host.docker.internal:5432/devdb
```

## Tool-Specific Configuration

### k3d

k3d runs in Docker and can access the PostgreSQL container via:
- `host.docker.internal` (standard)
- `host.k3d.internal` (k3d-specific)

No additional configuration needed if both containers are on the same Docker network.

### Minikube

Minikube runs in a VM (by default), so it requires special networking:

**Option 1**: Use host IP address
```bash
# Get host IP
minikube ssh "route -n | grep ^0.0.0.0 | awk '{print \$2}'"
```

**Option 2**: Use Docker driver
```bash
minikube start --driver=docker
```
Then use `host.docker.internal`.

### kind

kind runs in Docker and can access via `host.docker.internal`.

Ensure the kind cluster is created with `extraPortMappings` if needed:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
```

## Database Schema Management

**Important**: The database starts empty. All tables, indexes, and constraints are automatically created by the **Spring Boot Data Service** using:

```yaml
spring.jpa.hibernate.ddl-auto: update
```

The `init.sql` script only verifies the connection; it does NOT create tables.

## Network Details

### Custom Network: k8s-network

The PostgreSQL container runs on a custom Docker bridge network called `k8s-network`. This network can be shared with Kubernetes clusters (k3d, kind) to enable direct container-to-container communication.

**View network details:**
```bash
docker network inspect k8s-network
```

**Connect k3d cluster to the network:**
```bash
docker network connect k8s-network k3d-mycluster-server-0
```

## Data Persistence

**⚠️ No persistent volumes are configured.** This is intentional for development and testing:

- Data is ephemeral and stored only in the container's writable layer
- When the container is removed (`docker-compose down`), all data is lost
- When the container is restarted (`docker-compose restart`), data persists
- This ensures a clean state for each test run

**To add persistence** (not recommended for this project):
```yaml
volumes:
  - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

## Environment Variables

Default values are defined in `docker-compose.yml`. You can override them by creating a `.env` file (see `.env.example`):

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_DB` | `devdb` | Database name |
| `POSTGRES_USER` | `postgres` | Database user |
| `POSTGRES_PASSWORD` | `postgres` | Database password |
| `POSTGRES_PORT` | `5432` | Host port mapping |

## Troubleshooting

### Container won't start

**Check if port 5432 is already in use:**
```bash
lsof -i :5432
```

**Kill existing PostgreSQL processes:**
```bash
pkill -9 postgres
```

### Kubernetes pods can't connect

**1. Verify PostgreSQL is running:**
```bash
docker ps | grep postgres-devdb
```

**2. Test connection from host:**
```bash
psql -h localhost -p 5432 -U postgres -d devdb
```

**3. Check Kubernetes pod can resolve host:**
```bash
kubectl exec -it <data-service-pod> -- nslookup host.docker.internal
```

**4. Check Spring Boot logs:**
```bash
kubectl logs <data-service-pod>
```

Look for connection errors like:
```
Connection refused
Unknown host
```

**5. Verify network connectivity:**
```bash
kubectl exec -it <data-service-pod> -- nc -zv host.docker.internal 5432
```

### Health check failing

**Check PostgreSQL logs:**
```bash
docker-compose logs postgres
```

**Manually run health check:**
```bash
docker exec postgres-devdb pg_isready -U postgres -d devdb
```

### Need to reset database

**Stop and remove container (deletes all data):**
```bash
docker-compose down
docker-compose up -d
```

Spring Boot will recreate the schema on next startup.

## Maintenance Commands

### View real-time logs
```bash
docker-compose logs -f postgres
```

### Access PostgreSQL shell
```bash
docker exec -it postgres-devdb psql -U postgres -d devdb
```

### List all tables (after Spring Boot creates them)
```sql
\dt
```

### Check database size
```sql
SELECT pg_database_size('devdb');
```

### Restart container
```bash
docker-compose restart
```

### Remove container and network
```bash
docker-compose down
docker network rm k8s-network  # if needed
```

## Security Notes

**⚠️ This configuration is for LOCAL DEVELOPMENT ONLY.**

- Default credentials (postgres/postgres) are used
- No SSL/TLS encryption
- Database is exposed on host port 5432
- No firewall rules or network policies

Do NOT use this configuration in production environments.

## References

- [PostgreSQL Docker Official Image](https://hub.docker.com/_/postgres)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [Spring Boot DataSource Configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/application-properties.html#application-properties.data)
- [Hibernate DDL Auto](https://docs.jboss.org/hibernate/orm/current/userguide/html_single/Hibernate_User_Guide.html#configurations-hbmddl)
