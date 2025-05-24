import json
import os
import psycopg2
import requests # For calling StoreServiceLambda

# Database connection details from environment variables
DB_HOST = os.environ.get('DB_HOST')
DB_PORT = os.environ.get('DB_PORT', '5432')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')

# URL for StoreServiceLambda from environment variables
STORE_SERVICE_URL = os.environ.get('STORE_SERVICE_URL')

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
        raise e

def validate_store_exists(store_id):
    if not STORE_SERVICE_URL:
        print("STORE_SERVICE_URL environment variable is not set. Cannot validate store.")
        return False
    
    headers = {'Content-Type': 'application/json'}
    validation_payload_dict = {
        'action': 'getStore',
        'store_id': int(store_id)  # Ensure we send an integer
    }
    
    try:
        print(f"Calling StoreServiceLambda at {STORE_SERVICE_URL} to validate store_id: {store_id}")
        print(f"Sending payload: {validation_payload_dict}")
        response = requests.post(STORE_SERVICE_URL, headers=headers, json=validation_payload_dict, timeout=10)
        print(f"Response status code: {response.status_code}")
        print(f"Response text: {response.text}")
        
        response.raise_for_status()
        response_data = response.json()
        
        # Convert both to integers for comparison
        expected_store_id = int(store_id)
        returned_store_id = response_data.get('store_id')
        
        print(f"Expected store_id: {expected_store_id} (type: {type(expected_store_id)})")
        print(f"Returned store_id: {returned_store_id} (type: {type(returned_store_id)})")
        
        # Check if we got a successful response with the correct store_id
        if response.status_code == 200 and isinstance(response_data, dict) and returned_store_id == expected_store_id:
            print(f"Store validation successful for store_id: {store_id}")
            return True
        else:
            print(f"Store validation failed. Response from StoreService: {response_data}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"Error calling StoreServiceLambda: {e}")
        return False
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON response from StoreServiceLambda: {e}. Response text: {response.text if response else 'No response'}")
        return False
    except Exception as e:
        print(f"Unexpected error in store validation: {e}")
        return False

def lambda_handler(event, context):
    print(f"Raw event received: {json.dumps(event)}") # Log the raw event

    try:
        if 'body' in event and isinstance(event['body'], str):
            print(f"Attempting to parse event body: {event['body']}")
            data_for_processing = json.loads(event['body'])
        elif 'action' in event and 'payload' in event: 
            print("Using event directly as data for processing.")
            data_for_processing = event
        else: 
            print("Warning: Could not determine primary data source from event, attempting to use event or event['body'] if dict.")
            body_content = event.get('body', event)
            if isinstance(body_content, str):
                 data_for_processing = json.loads(body_content)
            elif isinstance(body_content, dict):
                 data_for_processing = body_content
            else:
                 raise ValueError("Unable to determine data for processing from event structure.")
        print(f"Data for processing: {json.dumps(data_for_processing)}")

    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in request body: {e}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Invalid JSON format in request body', 'details': str(e)})
        }
    except ValueError as e:
        print(f"ERROR: Problem determining data from event: {e}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Invalid event structure for processing', 'details': str(e)})
        }
    except Exception as e:
        print(f"ERROR: Unexpected error processing event: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error during event processing', 'details': str(e)})
        }

    action = data_for_processing.get('action')
    payload = data_for_processing.get('payload', {})
    response_body = {}
    status_code = 200
    conn = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if action == 'addItemToStore':
            store_id = payload.get('store_id')
            item_name = payload.get('item_name')
            quantity = payload.get('quantity', 0)
            price = payload.get('price', 0.0)

            if not all([store_id, item_name]):
                status_code = 400
                response_body = {'error': 'Missing required fields: store_id, item_name'}
            elif not validate_store_exists(store_id):
                status_code = 404 
                response_body = {'error': f'Store with store_id {store_id} not found or validation failed.'}
            else:
                cursor.execute(
                    "INSERT INTO inventoryitems (store_id, item_name, quantity, price) VALUES (%s, %s, %s, %s) RETURNING item_id",
                    (store_id, item_name, int(quantity), float(price))
                )
                item_id = cursor.fetchone()[0]
                conn.commit()
                response_body = {'message': 'Item added to store successfully', 'item_id': item_id}

        elif action == 'getStoreInventory':
            store_id = payload.get('store_id')
            if not store_id:
                status_code = 400
                response_body = {'error': 'Missing store_id'}
            else:
                cursor.execute("SELECT item_id, item_name, quantity, price FROM inventoryitems WHERE store_id = %s ORDER BY item_name", (store_id,))
                items = cursor.fetchall()
                response_body = [{'item_id': i[0], 'item_name': i[1], 'quantity': i[2], 'price': float(i[3])} for i in items]
        
        elif action == 'updateItemQuantity':
            item_id = payload.get('item_id')
            new_quantity = payload.get('quantity')
            if not item_id or new_quantity is None: 
                status_code = 400
                response_body = {'error': 'Missing required fields: item_id, quantity'}
            else:
                cursor.execute("UPDATE inventoryitems SET quantity = %s WHERE item_id = %s RETURNING store_id", (int(new_quantity), item_id))
                if cursor.rowcount == 0:
                    status_code = 404
                    response_body = {'error': 'Item not found'}
                else:
                    conn.commit()
                    response_body = {'message': 'Item quantity updated successfully', 'item_id': item_id, 'new_quantity': int(new_quantity)}
        else:
            status_code = 400
            response_body = {'error': f'Invalid action: {action}'}

    except psycopg2.Error as db_err:
        print(f"Database operation failed: {db_err}")
        status_code = 500
        response_body = {'error': 'Database operation failed', 'details': str(db_err)}
        if conn: conn.rollback()
    except requests.exceptions.RequestException as req_err: 
        print(f"Request to StoreService failed: {req_err}")
        status_code = 503 
        response_body = {'error': 'Failed to communicate with StoreService', 'details': str(req_err)}
    except Exception as e:
        print(f"Error processing request: {e}")
        status_code = 500
        response_body = {'error': 'Internal server error', 'details': str(e)}
        if conn: conn.rollback()
    finally:
        if conn:
            cursor.close()
            conn.close()
            print("Database connection closed.")

    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps(response_body)
    } 