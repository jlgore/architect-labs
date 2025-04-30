const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const path = require('path');

const app = express();
const port = 80;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());

// Serve static frontend files
app.use(express.static(path.join(__dirname, 'public')));

// Database configuration - this will be populated from environment variables
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'dbadmin',
  password: process.env.DB_PASSWORD || 'password',
  database: process.env.DB_NAME || 'cloudmart'
};

// Initialize database
async function initializeDatabase() {
  try {
    const connection = await mysql.createConnection({
      host: dbConfig.host,
      user: dbConfig.user,
      password: dbConfig.password
    });

    // Create database if it doesn't exist
    await connection.query(`CREATE DATABASE IF NOT EXISTS ${dbConfig.database}`);
    
    // Use the database
    await connection.query(`USE ${dbConfig.database}`);
    
    // Create products table
    await connection.query(`
      CREATE TABLE IF NOT EXISTS products (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        price DECIMAL(10, 2) NOT NULL,
        description TEXT,
        image VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);
    
    // Check if we need to insert sample data
    const [rows] = await connection.query('SELECT COUNT(*) as count FROM products');
    if (rows[0].count === 0) {
      // Insert sample products
      await connection.query(`
        INSERT INTO products (name, price, description, image) VALUES 
        ('Cloud Storage Plus', 29.99, 'Unlimited cloud storage for all your files', 'https://via.placeholder.com/300x200?text=Cloud+Storage'),
        ('Web Hosting Pro', 49.99, 'Professional web hosting with 99.9% uptime', 'https://via.placeholder.com/300x200?text=Web+Hosting'),
        ('Database Server', 99.99, 'High-performance database server with automatic backups', 'https://via.placeholder.com/300x200?text=Database'),
        ('API Gateway', 59.99, 'Secure gateway for all your API needs', 'https://via.placeholder.com/300x200?text=API+Gateway'),
        ('Load Balancer', 79.99, 'Distribute traffic efficiently across your servers', 'https://via.placeholder.com/300x200?text=Load+Balancer'),
        ('CDN Package', 39.99, 'Content delivery network for faster website loading', 'https://via.placeholder.com/300x200?text=CDN')
      `);
      console.log('Sample data inserted successfully');
    }

    await connection.end();
    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Error initializing database:', error);
  }
}

// Connect to the database
async function getConnection() {
  return await mysql.createConnection({
    host: dbConfig.host,
    user: dbConfig.user,
    password: dbConfig.password,
    database: dbConfig.database
  });
}

// API Routes

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// Get all products
app.get('/api/products', async (req, res) => {
  try {
    const connection = await getConnection();
    const [rows] = await connection.query('SELECT * FROM products');
    await connection.end();
    res.json(rows);
  } catch (error) {
    console.error('Error fetching products:', error);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

// Get a specific product
app.get('/api/products/:id', async (req, res) => {
  try {
    const connection = await getConnection();
    const [rows] = await connection.query('SELECT * FROM products WHERE id = ?', [req.params.id]);
    await connection.end();
    
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    res.json(rows[0]);
  } catch (error) {
    console.error('Error fetching product:', error);
    res.status(500).json({ error: 'Failed to fetch product' });
  }
});

// Create a new product
app.post('/api/products', async (req, res) => {
  try {
    const { name, price, description, image } = req.body;
    
    if (!name || !price) {
      return res.status(400).json({ error: 'Name and price are required' });
    }
    
    const connection = await getConnection();
    const [result] = await connection.query(
      'INSERT INTO products (name, price, description, image) VALUES (?, ?, ?, ?)',
      [name, price, description || null, image || null]
    );
    
    const [newProduct] = await connection.query('SELECT * FROM products WHERE id = ?', [result.insertId]);
    await connection.end();
    
    res.status(201).json(newProduct[0]);
  } catch (error) {
    console.error('Error creating product:', error);
    res.status(500).json({ error: 'Failed to create product' });
  }
});

// Update a product
app.put('/api/products/:id', async (req, res) => {
  try {
    const { name, price, description, image } = req.body;
    const productId = req.params.id;
    
    const connection = await getConnection();
    
    // Check if product exists
    const [existing] = await connection.query('SELECT * FROM products WHERE id = ?', [productId]);
    if (existing.length === 0) {
      await connection.end();
      return res.status(404).json({ error: 'Product not found' });
    }
    
    // Update product
    await connection.query(
      'UPDATE products SET name = ?, price = ?, description = ?, image = ? WHERE id = ?',
      [
        name || existing[0].name,
        price || existing[0].price,
        description !== undefined ? description : existing[0].description,
        image !== undefined ? image : existing[0].image,
        productId
      ]
    );
    
    // Get updated product
    const [updated] = await connection.query('SELECT * FROM products WHERE id = ?', [productId]);
    await connection.end();
    
    res.json(updated[0]);
  } catch (error) {
    console.error('Error updating product:', error);
    res.status(500).json({ error: 'Failed to update product' });
  }
});

// Delete a product
app.delete('/api/products/:id', async (req, res) => {
  try {
    const connection = await getConnection();
    
    // Check if product exists
    const [existing] = await connection.query('SELECT * FROM products WHERE id = ?', [req.params.id]);
    if (existing.length === 0) {
      await connection.end();
      return res.status(404).json({ error: 'Product not found' });
    }
    
    // Delete product
    await connection.query('DELETE FROM products WHERE id = ?', [req.params.id]);
    await connection.end();
    
    res.json({ message: 'Product deleted successfully' });
  } catch (error) {
    console.error('Error deleting product:', error);
    res.status(500).json({ error: 'Failed to delete product' });
  }
});

// Serve the frontend
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Start the server
app.listen(port, async () => {
  console.log(`CloudMart server running on port ${port}`);
  await initializeDatabase();
}); 