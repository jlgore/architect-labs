const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB.DocumentClient();

exports.getItemById = async (event) => {
  console.log('Processing get item by id request', JSON.stringify(event));
  const tableName = process.env.TABLE_NAME;
  const environment = process.env.ENVIRONMENT;
  const id = event.pathParameters && event.pathParameters.id;

  if (!id) {
    return {
      statusCode: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ message: 'Missing path parameter: id' })
    };
  }

  try {
    const params = { TableName: tableName, Key: { id } };
    const result = await dynamoDB.get(params).promise();

    if (!result.Item) {
      return {
        statusCode: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ message: 'Item not found' })
      };
    }

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ item: result.Item, environment })
    };
  } catch (error) {
    console.error('Error fetching item by id:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ message: 'Error fetching item', error: error.message })
    };
  }
}; 