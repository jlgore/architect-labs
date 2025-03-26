# Database Schema Differences

This directory contains equivalent schemas implemented in four major database systems: MySQL, PostgreSQL, Oracle, and Microsoft SQL Server. Each schema creates the same basic structure (users, products, orders, and order items) but demonstrates the unique syntax and features of each database system.

## Key Differences by Feature

### Auto-Incrementing Columns
- **MySQL**: `AUTO_INCREMENT`
- **PostgreSQL**: `BIGSERIAL`
- **Oracle**: Uses sequences (`CREATE SEQUENCE` + `DEFAULT sequence_name.NEXTVAL`)
- **SQL Server**: `IDENTITY(1,1)`

### Boolean Values
- **MySQL**: `TINYINT(1)` (0 = false, 1 = true)
- **PostgreSQL**: Native `BOOLEAN` type (TRUE/FALSE)
- **Oracle**: `NUMBER(1)` with CHECK constraint (0/1)
- **SQL Server**: `BIT` (0 = false, 1 = true)

### Timestamp/DateTime
- **MySQL**: `TIMESTAMP` with `ON UPDATE CURRENT_TIMESTAMP`
- **PostgreSQL**: `TIMESTAMP WITH TIME ZONE`
- **Oracle**: `TIMESTAMP` with `SYSTIMESTAMP`
- **SQL Server**: `DATETIME2(7)` with `GETDATE()`

### Large Text Fields
- **MySQL**: `TEXT`
- **PostgreSQL**: `TEXT`
- **Oracle**: `CLOB`
- **SQL Server**: `NVARCHAR(MAX)`

### String Fields
- **MySQL**: `VARCHAR`
- **PostgreSQL**: `VARCHAR`
- **Oracle**: `VARCHAR2`
- **SQL Server**: `NVARCHAR` (Unicode support)

### Enumerated Types
- **MySQL**: Native `ENUM` type
- **PostgreSQL**: Custom `TYPE` as `ENUM`
- **Oracle**: CHECK constraints on `VARCHAR2`
- **SQL Server**: CHECK constraints on `VARCHAR`

### Numeric Types
- **MySQL**: `INT`, `DECIMAL`
- **PostgreSQL**: `INTEGER`, `NUMERIC`
- **Oracle**: `NUMBER`
- **SQL Server**: `INT`, `DECIMAL`

### Trigger Syntax
```sql
-- MySQL
CREATE TRIGGER ... ON UPDATE CURRENT_TIMESTAMP

-- PostgreSQL
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Oracle
CREATE OR REPLACE TRIGGER ...
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

-- SQL Server
CREATE TRIGGER ...
AS
BEGIN
    UPDATE table SET updated_at = GETDATE()
    FROM table t INNER JOIN inserted i ON t.id = i.id;
END;
```

### Batch Separators
- **MySQL**: None required
- **PostgreSQL**: None required
- **Oracle**: Forward slash (`/`) after PL/SQL blocks
- **SQL Server**: `GO` between batches

### Unicode Support
- **MySQL**: Uses `utf8mb4` charset
- **PostgreSQL**: Native UTF-8 support
- **Oracle**: Uses `VARCHAR2` with NLS settings
- **SQL Server**: Uses `NVARCHAR` for Unicode

## Common Features Across All Databases
- Primary and Foreign Key constraints
- NOT NULL and UNIQUE constraints
- Default values
- Basic data types (numbers, strings, dates)
- Transaction support
- Index support

## Best Practices
1. Always specify precision for decimal/numeric types
2. Use appropriate Unicode support for international text
3. Consider timezone handling in datetime fields
4. Use appropriate constraints to maintain data integrity
5. Follow naming conventions for constraints and triggers
6. Consider performance implications of auto-updating fields 