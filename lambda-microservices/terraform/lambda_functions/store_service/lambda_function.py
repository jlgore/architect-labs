import json
import os
import psycopg2

# Database connection details from environment variables
DB_HOST = os.environ.get('DB_HOST')
DB_PORT = os.environ.get('DB_PORT', '5432')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            sslmode='require'
        )
        return conn
    except Exception as e:
        print(f"Database connection failed: {e}")
        raise e  # Re-raise exception to signal error

def initialize_database():
    """Create database tables if they don't exist"""
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            # Create stores table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS stores (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    address VARCHAR(500) NOT NULL,
                    city VARCHAR(100) NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Create inventory table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS inventory (
                    id SERIAL PRIMARY KEY,
                    store_id INTEGER NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
                    item_name VARCHAR(255) NOT NULL,
                    quantity INTEGER NOT NULL DEFAULT 0,
                    price DECIMAL(10,2) NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(store_id, item_name)
                )
            """)
            
            # Create gas_prices table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS gas_prices (
                    id SERIAL PRIMARY KEY,
                    store_id INTEGER NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
                    fuel_type VARCHAR(50) NOT NULL,
                    price DECIMAL(10,3) NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(store_id, fuel_type)
                )
            """)
            
            # Create indexes
            cur.execute("CREATE INDEX IF NOT EXISTS idx_inventory_store_id ON inventory(store_id)")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_gas_prices_store_id ON gas_prices(store_id)")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_stores_name ON stores(name)")
            
            conn.commit()
            print("Database tables initialized successfully")
        conn.close()
    except Exception as e:
        print(f"Error initializing database: {e}")
        # Don't raise the error - we want the Lambda to continue working even if table creation fails

# Initialize database tables on Lambda startup
initialize_database()

def lambda_handler(event, context):
    # For Lambda Function URL, the actual request body is in event['body'] as a JSON string
    print(f"Raw event received: {json.dumps(event)}")

    try:
        # Parse the request body
        if 'body' in event and isinstance(event['body'], str):
            print(f"Attempting to parse event body: {event['body']}")
            body = json.loads(event['body'])
        else:
            body = event.get('body', {})  # In case body is already parsed
            print(f"Using event body as is: {body}")
        
        action = body.get('action')
        
        if not action:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing action parameter'}),
                'headers': {'Content-Type': 'application/json'}
            }
        
        if action == 'addStore':
            # Extract store data from the request
            store_data = body.get('store')
            if not store_data or 'name' not in store_data or 'address' not in store_data:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'Missing required store data (name, address)'}),
                    'headers': {'Content-Type': 'application/json'}
                }
            
            # Get database connection
            conn = get_db_connection()
            try:
                with conn.cursor() as cur:
                    # Insert new store (updated to match table schema)
                    cur.execute(
                        """
                        INSERT INTO stores (name, address, city)
                        VALUES (%s, %s, %s)
                        RETURNING id, name, address, city, created_at
                        """,
                        (store_data['name'], store_data['address'], store_data.get('city', ''))
                    )
                    result = cur.fetchone()
                    conn.commit()
                    
                    # Return the created store
                    return {
                        'statusCode': 201,
                        'body': json.dumps({
                            'store_id': result[0],
                            'name': result[1],
                            'address': result[2],
                            'city': result[3],
                            'created_at': result[4].isoformat()
                        }),
                        'headers': {'Content-Type': 'application/json'}
                    }
            finally:
                conn.close()
                
        elif action == 'getStore':
            store_id = body.get('store_id')
            if not store_id:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'Missing store_id parameter'}),
                    'headers': {'Content-Type': 'application/json'}
                }
            
            conn = get_db_connection()
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT id, name, address, city, created_at
                        FROM stores
                        WHERE id = %s
                        """,
                        (store_id,)
                    )
                    result = cur.fetchone()
                    
                    if not result:
                        return {
                            'statusCode': 404,
                            'body': json.dumps({'error': 'Store not found'}),
                            'headers': {'Content-Type': 'application/json'}
                        }
                    
                    return {
                        'statusCode': 200,
                        'body': json.dumps({
                            'store_id': result[0],
                            'name': result[1],
                            'address': result[2],
                            'city': result[3],
                            'created_at': result[4].isoformat()
                        }),
                        'headers': {'Content-Type': 'application/json'}
                    }
            finally:
                conn.close()
                
        elif action == 'listStores':
            conn = get_db_connection()
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT id, name, address, city, created_at
                        FROM stores
                        ORDER BY name
                        """
                    )
                    stores = []
                    for row in cur.fetchall():
                        stores.append({
                            'store_id': row[0],
                            'name': row[1],
                            'address': row[2],
                            'city': row[3],
                            'created_at': row[4].isoformat()
                        })
                    
                    return {
                        'statusCode': 200,
                        'body': json.dumps({'stores': stores}),
                        'headers': {'Content-Type': 'application/json'}
                    }
            finally:
                conn.close()
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Unknown action: {action}'}),
                'headers': {'Content-Type': 'application/json'}
            }
            
    except json.JSONDecodeError as e:
        print(f"Invalid JSON in request body: {e}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON in request body'}),
            'headers': {'Content-Type': 'application/json'}
        }
    except Exception as e:
        print(f"Error processing request: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error', 'details': str(e)}),
            'headers': {'Content-Type': 'application/json'}
        } 