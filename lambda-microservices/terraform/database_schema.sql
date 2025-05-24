-- QuickMart Database Schema (PostgreSQL)
-- This file contains the corrected schema with lowercase table names and proper constraints

-- Stores Table
CREATE TABLE stores (
    store_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(255),
    city VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- InventoryItems Table
CREATE TABLE inventoryitems (
    item_id SERIAL PRIMARY KEY,
    store_id INT NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    quantity INT DEFAULT 0,
    price DECIMAL(10, 2) DEFAULT 0.00,
    CONSTRAINT fk_store
        FOREIGN KEY(store_id)
        REFERENCES stores(store_id)
        ON DELETE CASCADE
);

-- GasPrices Table
CREATE TABLE gasprices (
    gas_price_id SERIAL PRIMARY KEY,
    store_id INT NOT NULL,
    fuel_type VARCHAR(50) NOT NULL, -- e.g., 'Regular', 'Premium', 'Diesel'
    price DECIMAL(10, 3) NOT NULL, -- Prices per gallon/litre often go to 3 decimal places
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_store_gas
        FOREIGN KEY(store_id)
        REFERENCES stores(store_id)
        ON DELETE CASCADE,
    CONSTRAINT unique_store_fuel UNIQUE (store_id, fuel_type)
);

-- Performance indexes
CREATE INDEX idx_inventoryitems_store_id ON inventoryitems(store_id);
CREATE INDEX idx_gasprices_store_id ON gasprices(store_id);

-- Sample data (optional)
INSERT INTO stores (name, address, city) VALUES 
    ('QuickMart Downtown', '123 Main St', 'Anytown'),
    ('QuickMart Highway', '456 Route 1', 'Nextville');

-- Comments on schema design:
-- 1. Uses lowercase table names to match Lambda code
-- 2. Added created_at column to stores table for consistency
-- 3. Added unique constraint on (store_id, fuel_type) for UPSERT operations
-- 4. Uses proper PostgreSQL data types and constraints
-- 5. Foreign key constraints ensure data integrity 