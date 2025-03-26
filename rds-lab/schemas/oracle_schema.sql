-- Oracle Schema

-- Sequences for auto-incrementing columns
CREATE SEQUENCE users_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE products_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE orders_seq START WITH 1 INCREMENT BY 1;

-- Create a type for order status
CREATE TYPE order_status_type AS OBJECT (
    status VARCHAR2(20)
);
/

CREATE TABLE users (
    id NUMBER(19) DEFAULT users_seq.NEXTVAL PRIMARY KEY,
    username VARCHAR2(50) NOT NULL UNIQUE,
    email VARCHAR2(255) NOT NULL UNIQUE,
    password_hash CHAR(60) NOT NULL,
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE products (
    id NUMBER(19) DEFAULT products_seq.NEXTVAL PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    description CLOB,
    price NUMBER(10,2) NOT NULL,
    stock_quantity NUMBER(10) DEFAULT 0 CONSTRAINT stock_quantity_check CHECK (stock_quantity >= 0),
    is_active NUMBER(1) DEFAULT 1 CONSTRAINT is_active_check CHECK (is_active IN (0,1)),
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE orders (
    id NUMBER(19) DEFAULT orders_seq.NEXTVAL PRIMARY KEY,
    user_id NUMBER(19) NOT NULL,
    order_date TIMESTAMP DEFAULT SYSTIMESTAMP,
    total_amount NUMBER(10,2) NOT NULL,
    status VARCHAR2(20) DEFAULT 'pending' 
        CONSTRAINT status_check CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
    shipping_address CLOB NOT NULL,
    CONSTRAINT fk_orders_users FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE order_items (
    order_id NUMBER(19) NOT NULL,
    product_id NUMBER(19) NOT NULL,
    quantity NUMBER(10) NOT NULL CONSTRAINT quantity_check CHECK (quantity > 0),
    unit_price NUMBER(10,2) NOT NULL,
    CONSTRAINT pk_order_items PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_items_orders FOREIGN KEY (order_id) REFERENCES orders(id),
    CONSTRAINT fk_items_products FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Trigger for updating the updated_at timestamp
CREATE OR REPLACE TRIGGER users_update_trigger
    BEFORE UPDATE ON users
    FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER products_update_trigger
    BEFORE UPDATE ON products
    FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

-- Comments on Oracle specific features:
-- 1. Uses sequences and triggers for auto-incrementing columns
-- 2. VARCHAR2 instead of VARCHAR
-- 3. CLOB for large text fields
-- 4. NUMBER type instead of INT/BIGINT
-- 5. SYSTIMESTAMP for current time
-- 6. Different trigger syntax with BEGIN/END blocks
-- 7. CHECK constraints for enums
-- 8. NUMBER(1) for boolean values (0/1)
-- 9. Forward slash (/) required after PL/SQL blocks 