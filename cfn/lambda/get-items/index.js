const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB.DocumentClient();

exports.getItems = async (event) => {
  console.log('Processing get items request', JSON.stringify(event));
  
  const tableName = process.env.TABLE_NAME;
  const environment = process.env.ENVIRONMENT;
  
  try {
    // Get all items from the DynamoDB table
    const params = {
      TableName: tableName
    };
    
    const result = await dynamoDB.scan(params).promise();
    
    // Return the response
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        items: result.Items,
        environment: environment,
        count: result.Count
      })
    };
  } catch (error) {
    console.error('Error fetching items:', error);
    
    // Return error response
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        message: 'Error fetching items',
        error: error.message
      })
    };
  }
}; 