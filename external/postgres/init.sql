-- PostgreSQL Initialization Script
-- This file is executed automatically when the container is first created
--
-- NOTE: This script creates an empty database structure only.
-- All necessary tables, indexes, and constraints will be automatically
-- created by the Spring Boot Data Service using Hibernate DDL (ddl-auto: update).
--
-- Database: devdb
-- User: postgres
-- Password: postgres

-- Verify database connection
SELECT 'PostgreSQL database initialized successfully' AS status;

-- Show current database info
SELECT current_database() AS database_name,
       current_user AS connected_user,
       version() AS postgresql_version;

-- The database 'devdb' is created automatically by POSTGRES_DB environment variable
-- No table creation needed here - Spring Boot handles schema management
