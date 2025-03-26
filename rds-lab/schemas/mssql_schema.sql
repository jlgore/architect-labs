-- Microsoft SQL Server Schema

CREATE TABLE users (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    username NVARCHAR(50) NOT NULL UNIQUE,
    email NVARCHAR(255) NOT NULL UNIQUE,
    password_hash CHAR(60) NOT NULL,
    created_at DATETIME2(7) DEFAULT GETDATE(),
    updated_at DATETIME2(7) DEFAULT GETDATE()
);

CREATE TABLE products (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    description NVARCHAR(MAX),
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT DEFAULT 0 CHECK (stock_quantity >= 0),
    is_active BIT DEFAULT 1,
    created_at DATETIME2(7) DEFAULT GETDATE(),
    updated_at DATETIME2(7) DEFAULT GETDATE()
);

-- Create a custom type for order status
CREATE TYPE order_status FROM VARCHAR(20) NOT NULL;
GO

CREATE TABLE orders (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id BIGINT NOT NULL,
    order_date DATETIME2(7) DEFAULT GETDATE(),
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
    shipping_address NVARCHAR(MAX) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE order_items (
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Triggers for updating the updated_at timestamp
CREATE TRIGGER trg_users_update
ON users
AFTER UPDATE
AS
BEGIN
    UPDATE users
    SET updated_at = GETDATE()
    FROM users u
    INNER JOIN inserted i ON u.id = i.id;
END;
GO

CREATE TRIGGER trg_products_update
ON products
AFTER UPDATE
AS
BEGIN
    UPDATE products
    SET updated_at = GETDATE()
    FROM products p
    INNER JOIN inserted i ON p.id = i.id;
END;
GO

-- Comments on SQL Server specific features:
-- 1. Uses IDENTITY for auto-incrementing columns
-- 2. NVARCHAR for Unicode string support
-- 3. NVARCHAR(MAX) for large text fields
-- 4. DATETIME2(7) for high-precision timestamps
-- 5. BIT type for boolean values
-- 6. GETDATE() for current timestamp
-- 7. Different trigger syntax with FROM/INNER JOIN
-- 8. GO keyword to separate batches
-- 9. Custom types require separate CREATE TYPE statement 