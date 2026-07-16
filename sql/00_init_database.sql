-- ============================================
-- Script:    00_init_database.sql
-- Purpose:   Create database and schemas (Medallion Architecture)
-- Project:   SuperStore Analytics
-- ============================================

USE master;
GO
SET NOCOUNT ON;
GO

-- Drop database if it exists (safe re-run for dev/setup)
IF DB_ID('SuperStoreProject') IS NOT NULL
BEGIN
    ALTER DATABASE SuperStoreProject SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SuperStoreProject;
    PRINT 'Existing database dropped.';
END
GO

-- Create database
CREATE DATABASE SuperStoreProject;
GO

USE SuperStoreProject;
GO

-- Create schemas for Medallion Architecture (Bronze -> Silver -> Gold)
IF SCHEMA_ID('bronze') IS NULL
    EXEC('CREATE SCHEMA bronze');
GO

IF SCHEMA_ID('silver') IS NULL
    EXEC('CREATE SCHEMA silver');
GO

IF SCHEMA_ID('gold') IS NULL
    EXEC('CREATE SCHEMA gold');
GO

PRINT 'Database and schemas created successfully.';
GO