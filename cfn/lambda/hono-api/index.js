const { Hono } = require('hono');
const { handle } = require('@hono/aws-lambda');
const mysql = require('mysql2/promise');
const { ulid } = require('ulid');

// Database configuration from environment variables
const dbConfig = {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// Create MySQL connection pool
let pool;

// Initialize database
async function initializeDb() {
  if (!pool) {
    pool = mysql.createPool(dbConfig);
    
    // Create items table if it doesn't exist
    await pool.execute(`
      CREATE TABLE IF NOT EXISTS items (
        id VARCHAR(36) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        price DECIMAL(10, 2),
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        data JSON
      )
    `);
    
    console.log('Database initialized');
  }
  return pool;
}

// Create Hono app
const app = new Hono();

// Middleware to add CORS headers
app.use('*', async (c, next) => {
  await next();
  c.header('Access-Control-Allow-Origin', '*');
  c.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  c.header('Access-Control-Allow-Headers', 'Content-Type, X-Api-Key, X-Amz-Date');
  
  if (c.req.method === 'OPTIONS') {
    return c.status(204);
  }
});

// Error handling middleware
app.use('*', async (c, next) => {
  try {
    await next();
  } catch (error) {
    console.error('API Error:', error);
    return c.json({ 
      message: 'Internal Server Error', 
      error: error.message 
    }, 500);
  }
});

// Get all items
app.get('/items', async (c) => {
  const db = await initializeDb();
  
  const [rows] = await db.execute('SELECT * FROM items');
  
  return c.json({ 
    items: rows,
    environment: process.env.ENVIRONMENT
  });
});

// Get item by ID
app.get('/items/:id', async (c) => {
  const id = c.req.param('id');
  const db = await initializeDb();
  
  const [rows] = await db.execute('SELECT * FROM items WHERE id = ?', [id]);
  
  if (rows.length === 0) {
    return c.json({ message: 'Item not found' }, 404);
  }
  
  return c.json({ 
    item: rows[0],
    environment: process.env.ENVIRONMENT
  });
});

// Create item
app.post('/items', async (c) => {
  const body = await c.req.json();
  
  if (!body || Object.keys(body).length === 0) {
    return c.json({ message: 'Request body is required' }, 400);
  }
  
  const db = await initializeDb();
  
  // Create item with a new ID
  const id = ulid();
  const now = new Date().toISOString();
  
  // Extract known fields from body
  const { name, description, price } = body;
  
  // Store additional fields in JSON data column
  const additionalData = { ...body };
  delete additionalData.name;
  delete additionalData.description;
  delete additionalData.price;
  
  const dataJSON = JSON.stringify(additionalData);
  
  await db.execute(
    'INSERT INTO items (id, name, description, price, createdAt, updatedAt, data) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [id, name, description, price, now, now, dataJSON]
  );
  
  // Get the created item
  const [rows] = await db.execute('SELECT * FROM items WHERE id = ?', [id]);
  
  return c.json({ 
    message: 'Item created successfully',
    item: rows[0],
    environment: process.env.ENVIRONMENT
  }, 201);
});

// Update item
app.put('/items/:id', async (c) => {
  const id = c.req.param('id');
  const body = await c.req.json();
  
  if (!body || Object.keys(body).length === 0) {
    return c.json({ message: 'Request body is required' }, 400);
  }
  
  const db = await initializeDb();
  
  // Check if item exists
  const [existingRows] = await db.execute('SELECT * FROM items WHERE id = ?', [id]);
  
  if (existingRows.length === 0) {
    return c.json({ message: 'Item not found' }, 404);
  }
  
  // Extract known fields from body
  const { name, description, price } = body;
  
  // Store additional fields in JSON data column
  const additionalData = { ...body };
  delete additionalData.name;
  delete additionalData.description;
  delete additionalData.price;
  
  const dataJSON = JSON.stringify(additionalData);
  
  // Update the item
  await db.execute(
    'UPDATE items SET name = ?, description = ?, price = ?, data = ? WHERE id = ?',
    [name, description, price, dataJSON, id]
  );
  
  // Get the updated item
  const [rows] = await db.execute('SELECT * FROM items WHERE id = ?', [id]);
  
  return c.json({ 
    message: 'Item updated successfully',
    item: rows[0],
    environment: process.env.ENVIRONMENT
  });
});

// Delete item
app.delete('/items/:id', async (c) => {
  const id = c.req.param('id');
  const db = await initializeDb();
  
  // Check if item exists
  const [existingRows] = await db.execute('SELECT * FROM items WHERE id = ?', [id]);
  
  if (existingRows.length === 0) {
    return c.json({ message: 'Item not found' }, 404);
  }
  
  const deletedItem = existingRows[0];
  
  // Delete the item
  await db.execute('DELETE FROM items WHERE id = ?', [id]);
  
  return c.json({ 
    message: 'Item deleted successfully',
    item: deletedItem,
    environment: process.env.ENVIRONMENT
  });
});

// The Lambda handler
exports.handler = async (event, context) => {
  // Enable connection reuse in Lambda
  context.callbackWaitsForEmptyEventLoop = false;
  
  console.log('Received event:', JSON.stringify(event, null, 2));
  return await handle(app, event, context);
}; 