const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB.DocumentClient();

exports.updateItem = async (event) => {
  console.log('Processing update item request', JSON.stringify(event));
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

  let requestBody;
  try {
    requestBody = JSON.parse(event.body);
  } catch (parseError) {
    console.error('Error parsing request body:', parseError);
    return {
      statusCode: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ message: 'Invalid JSON in request body' })
    };
  }

  const updateExpressions = [];
  const ExpressionAttributeNames = {};
  const ExpressionAttributeValues = {};

  if (requestBody.name !== undefined) {
    updateExpressions.push('#name = :name');
    ExpressionAttributeNames['#name'] = 'name';
    ExpressionAttributeValues[':name'] = requestBody.name;
  }

  if (requestBody.description !== undefined) {
    updateExpressions.push('description = :description');
    ExpressionAttributeValues[':description'] = requestBody.description;
  }

  if (updateExpressions.length === 0) {
    return {
      statusCode: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ message: 'No valid fields to update' })
    };
  }

  const UpdateExpression = 'SET ' + updateExpressions.join(', ');

  try {
    const params = {
      TableName: tableName,
      Key: { id },
      UpdateExpression,
      ExpressionAttributeNames,
      ExpressionAttributeValues,
      ReturnValues: 'ALL_NEW'
    };

    const result = await dynamoDB.update(params).promise();

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ item: result.Attributes, environment })
    };
  } catch (error) {
    console.error('Error updating item:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ message: 'Error updating item', error: error.message })
    };
  }
}; 