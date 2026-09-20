import { Pool } from 'pg';
import { Resource } from 'sst';

// Create a singleton database client that uses the Postgres connection from SST
let pool: any = null;

export function getDbClient() {
  if (!pool) {
    pool = new Pool({
      host: Resource.MyDatabase.host,
      port: Resource.MyDatabase.port,
      user: Resource.MyDatabase.username,
      password: Resource.MyDatabase.password,
      database: Resource.MyDatabase.defaultDatabaseName,
      ssl: {
        rejectUnauthorized: false, // Required for some connections
      },
    });
  }
  return pool;
}

// Initialize the database with a table for our data if it doesn't exist
export async function initDatabase() {
  const client = await getDbClient().connect();
  
  try {
    // Create the items table if it doesn't exist
    await client.query(`
      CREATE TABLE IF NOT EXISTS items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        timestamp TIMESTAMP NOT NULL DEFAULT NOW()
      )
    `);
    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Error initializing database:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Data access functions
export async function getItem(id: string) {
  const client = await getDbClient().connect();
  
  try {
    const result = await client.query(
      'SELECT * FROM items WHERE id = $1',
      [id]
    );
    
    if (result.rows.length === 0) {
      // If item doesn't exist, create it
      const newItem = {
        id,
        name: `Item ${id}`,
        description: `This is item ${id} from the database`,
        timestamp: new Date()
      };
      
      await client.query(
        'INSERT INTO items (id, name, description, timestamp) VALUES ($1, $2, $3, $4)',
        [newItem.id, newItem.name, newItem.description, newItem.timestamp]
      );
      
      return newItem;
    }
    
    return result.rows[0];
  } catch (error) {
    console.error('Error getting item from database:', error);
    throw error;
  } finally {
    client.release();
  }
} 