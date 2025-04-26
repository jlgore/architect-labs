const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const dynamoDB = new AWS.DynamoDB.DocumentClient();

exports.createItem = async (event) => {
  console.log('Processing create item request', JSON.stringify(event));
  
  const tableName = process.env.TABLE_NAME;
  const environment = process.env.ENVIRONMENT;
  
  try {
    // Parse the request body
    const requestBody = JSON.parse(event.body);
    
    // Validate required fields
    if (!requestBody.name) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
          message: 'Missing required field: name'
        })
      };
    }
    
    // Create a new item with unique ID
    const item = {
      id: uuidv4(),
      name: requestBody.name,
      description: requestBody.description || '',
      createdAt: new Date().toISOString(),
      environment: environment,
      ...requestBody
    };
    
    // Save to DynamoDB
    const params = {
      TableName: tableName,
      Item: item
    };
    
    await dynamoDB.put(params).promise();
    
    // Return success response
    return {
      statusCode: 201,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        message: 'Item created successfully',
        item: item
      })
    };
  } catch (error) {
    console.error('Error creating item:', error);
    
    // Return error response
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        message: 'Error creating item',
        error: error.message
      })
    };
  }
}; 