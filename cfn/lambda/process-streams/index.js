const AWS = require('aws-sdk');
const sns = new AWS.SNS();

exports.processStream = async (event) => {
  console.log('Processing DynamoDB Stream:', JSON.stringify(event, null, 2));
  
  const ENVIRONMENT = process.env.ENVIRONMENT;
  const NOTIFICATION_TOPIC = process.env.NOTIFICATION_TOPIC;
  
  try {
    // Process each record in the DynamoDB stream
    for (const record of event.Records) {
      // Extract the event type and data
      const eventName = record.eventName; // INSERT, MODIFY, REMOVE
      const dynamoRecord = record.dynamodb;
      
      let message;
      let subject;
      
      if (eventName === 'INSERT') {
        const newItem = AWS.DynamoDB.Converter.unmarshall(dynamoRecord.NewImage);
        subject = `[${ENVIRONMENT}] New Item Created: ${newItem.id}`;
        message = JSON.stringify({
          event: 'ITEM_CREATED',
          environment: ENVIRONMENT,
          item: newItem,
          timestamp: new Date().toISOString()
        }, null, 2);
      }
      else if (eventName === 'MODIFY') {
        const oldItem = AWS.DynamoDB.Converter.unmarshall(dynamoRecord.OldImage);
        const newItem = AWS.DynamoDB.Converter.unmarshall(dynamoRecord.NewImage);
        subject = `[${ENVIRONMENT}] Item Updated: ${newItem.id}`;
        message = JSON.stringify({
          event: 'ITEM_UPDATED',
          environment: ENVIRONMENT,
          oldItem,
          newItem,
          timestamp: new Date().toISOString()
        }, null, 2);
      }
      else if (eventName === 'REMOVE') {
        const oldItem = AWS.DynamoDB.Converter.unmarshall(dynamoRecord.OldImage);
        subject = `[${ENVIRONMENT}] Item Deleted: ${oldItem.id}`;
        message = JSON.stringify({
          event: 'ITEM_DELETED',
          environment: ENVIRONMENT,
          item: oldItem,
          timestamp: new Date().toISOString()
        }, null, 2);
      }
      
      // Publish the notification if we have a message
      if (message) {
        await sns.publish({
          TopicArn: NOTIFICATION_TOPIC,
          Subject: subject,
          Message: message
        }).promise();
        
        console.log(`Published notification for ${eventName} event`);
      }
    }
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Successfully processed DynamoDB stream events',
        recordsProcessed: event.Records.length
      })
    };
  } catch (error) {
    console.error('Error processing DynamoDB stream:', error);
    throw error;
  }
}; 