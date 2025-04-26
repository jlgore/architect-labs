const { Hono } = require('hono');
const { handle } = require('@hono/aws-lambda');
const AWS = require('aws-sdk');
const { ulid } = require('ulid');

// Initialize DynamoDB client
const dynamoDB = new AWS.DynamoDB.DocumentClient();
const TABLE_NAME = process.env.TABLE_NAME;
const ENVIRONMENT = process.env.ENVIRONMENT;

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
  const params = { TableName: TABLE_NAME };
  const result = await dynamoDB.scan(params).promise();
  
  return c.json({ 
    items: result.Items,
    environment: ENVIRONMENT
  });
});

// Get item by ID
app.get('/items/:id', async (c) => {
  const id = c.req.param('id');
  
  const params = { 
    TableName: TABLE_NAME, 
    Key: { id } 
  };
  
  const result = await dynamoDB.get(params).promise();
  
  if (!result.Item) {
    return c.json({ message: 'Item not found' }, 404);
  }
  
  return c.json({ 
    item: result.Item,
    environment: ENVIRONMENT
  });
});

// Create item
app.post('/items', async (c) => {
  const body = await c.req.json();
  
  if (!body || Object.keys(body).length === 0) {
    return c.json({ message: 'Request body is required' }, 400);
  }
  
  const item = {
    id: ulid(),
    ...body,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
  
  const params = {
    TableName: TABLE_NAME,
    Item: item
  };
  
  await dynamoDB.put(params).promise();
  
  return c.json({ 
    message: 'Item created successfully',
    item,
    environment: ENVIRONMENT
  }, 201);
});

// Update item
app.put('/items/:id', async (c) => {
  const id = c.req.param('id');
  const body = await c.req.json();
  
  if (!body || Object.keys(body).length === 0) {
    return c.json({ message: 'Request body is required' }, 400);
  }
  
  // First check if item exists
  const getParams = {
    TableName: TABLE_NAME,
    Key: { id }
  };
  
  const existingItem = await dynamoDB.get(getParams).promise();
  
  if (!existingItem.Item) {
    return c.json({ message: 'Item not found' }, 404);
  }
  
  // Update the item
  const updateExpressions = [];
  const expressionAttributeNames = {};
  const expressionAttributeValues = {};
  
  Object.keys(body).forEach(key => {
    if (key !== 'id') { // Prevent updating the primary key
      updateExpressions.push(`#${key} = :${key}`);
      expressionAttributeNames[`#${key}`] = key;
      expressionAttributeValues[`:${key}`] = body[key];
    }
  });
  
  // Add updatedAt timestamp
  updateExpressions.push('#updatedAt = :updatedAt');
  expressionAttributeNames['#updatedAt'] = 'updatedAt';
  expressionAttributeValues[':updatedAt'] = new Date().toISOString();
  
  const updateParams = {
    TableName: TABLE_NAME,
    Key: { id },
    UpdateExpression: `SET ${updateExpressions.join(', ')}`,
    ExpressionAttributeNames: expressionAttributeNames,
    ExpressionAttributeValues: expressionAttributeValues,
    ReturnValues: 'ALL_NEW'
  };
  
  const result = await dynamoDB.update(updateParams).promise();
  
  return c.json({ 
    message: 'Item updated successfully',
    item: result.Attributes,
    environment: ENVIRONMENT
  });
});

// Delete item
app.delete('/items/:id', async (c) => {
  const id = c.req.param('id');
  
  // First check if item exists
  const getParams = {
    TableName: TABLE_NAME,
    Key: { id }
  };
  
  const existingItem = await dynamoDB.get(getParams).promise();
  
  if (!existingItem.Item) {
    return c.json({ message: 'Item not found' }, 404);
  }
  
  const deleteParams = {
    TableName: TABLE_NAME,
    Key: { id },
    ReturnValues: 'ALL_OLD'
  };
  
  const result = await dynamoDB.delete(deleteParams).promise();
  
  return c.json({ 
    message: 'Item deleted successfully',
    item: result.Attributes,
    environment: ENVIRONMENT
  });
});

// The Lambda handler
exports.handler = async (event, context) => {
  console.log('Received event:', JSON.stringify(event, null, 2));
  return await handle(app, event, context);
}; 