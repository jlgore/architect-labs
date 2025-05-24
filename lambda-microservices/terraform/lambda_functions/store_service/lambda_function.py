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
            password=DB_PASSWORD
        )
        return conn
    except Exception as e:
        print(f"Database connection failed: {e}")
        raise e  # Re-raise exception to signal error

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
                    # Insert new store
                    cur.execute(
                        """
                        INSERT INTO stores (name, address)
                        VALUES (%s, %s)
                        RETURNING store_id, name, address, created_at
                        """,
                        (store_data['name'], store_data['address'])
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
                            'created_at': result[3].isoformat()
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
                        SELECT store_id, name, address, created_at
                        FROM stores
                        WHERE store_id = %s
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
                            'created_at': result[3].isoformat()
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
                        SELECT store_id, name, address, created_at
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
                            'created_at': row[3].isoformat()
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