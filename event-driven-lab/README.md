# Event-Driven Architecture Lab

This lab teaches core event-driven design patterns on AWS using inexpensive managed services:

- Amazon SNS for fanout
- Amazon SQS for buffering and decoupling
- Amazon SQS dead-letter queues for failure isolation
- optional EventBridge discussion for routing and integration patterns

The goal is to practice architectural behavior, not just create queues and topics.

## Learning Objectives

By the end of this lab, you should be able to:

- Explain when to use SNS, SQS, and DLQs together
- Design a fanout workflow where one event reaches multiple consumers
- Configure a dead-letter queue for messages that fail repeatedly
- Understand visibility timeout, retention, and redrive policy tradeoffs
- Compare event fanout with direct service-to-service calls
- Recognize when EventBridge is a better fit than SNS or direct queue writes

## Scenario

You are designing the event pipeline for `Pixel Pets Shop`, an online store that sells digital pet collectibles.

When an order is placed, multiple systems need to react:

- the `fulfillment` system prepares the digital item
- the `analytics` system records the purchase
- the `notifications` system sends a customer message later

Instead of tightly coupling these systems with direct synchronous calls, you will publish an event and let multiple consumers handle it independently.

## Why This Lab Matters

This is one of the most important Solutions Architect patterns:

- producers should not need to know every consumer
- consumers should be able to fail independently
- bursts of traffic should be buffered
- bad messages should be isolated, not silently lost

## Cost

This lab is intentionally inexpensive:

- SNS topics and SQS queues are low cost at small scale
- the lab uses tiny JSON messages
- no EC2, RDS, NAT, or Lambda runtime charges are required for the base lab

## Architecture

Base architecture:

- order events published to an SNS topic
- SNS fans out to multiple SQS queues
- one queue uses a DLQ for poison-message handling
- consumers poll messages from their own queue

Why this is better than direct calls:

- the producer publishes once
- subscribers can be added later without changing producer code
- one failing consumer does not block the others
- queues absorb bursts and retries

## Prerequisites

- AWS CLI configured with permissions for SNS and SQS
- `jq` installed

## Lab Overview

1. Create an SNS topic for order events
2. Create three SQS queues and one DLQ
3. Subscribe the queues to the topic
4. Publish order events
5. Consume messages from each queue
6. Simulate a failing consumer and move messages to the DLQ
7. Inspect retry and redrive behavior
8. Clean up

## Step 1: Set Variables

```bash
LAB_ID=$(date +%Y%m%d%H%M%S)
AWS_REGION=$(aws configure get region)

if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi

TOPIC_NAME="pixel-pets-orders-${LAB_ID}"
FULFILLMENT_QUEUE="pixel-pets-fulfillment-${LAB_ID}"
ANALYTICS_QUEUE="pixel-pets-analytics-${LAB_ID}"
NOTIFICATIONS_QUEUE="pixel-pets-notifications-${LAB_ID}"
NOTIFICATIONS_DLQ="pixel-pets-notifications-dlq-${LAB_ID}"

echo "Using region: $AWS_REGION"
echo "Topic: $TOPIC_NAME"
```

## Step 2: Create the SNS Topic

```bash
TOPIC_ARN=$(aws sns create-topic \
  --name "$TOPIC_NAME" \
  --query 'TopicArn' \
  --output text)

echo "Topic ARN: $TOPIC_ARN"
```

This topic represents the event stream for completed orders.

## Step 3: Create the Queues

Create the dead-letter queue first:

```bash
NOTIFICATIONS_DLQ_URL=$(aws sqs create-queue \
  --queue-name "$NOTIFICATIONS_DLQ" \
  --query 'QueueUrl' \
  --output text)

NOTIFICATIONS_DLQ_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$NOTIFICATIONS_DLQ_URL" \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text)
```

Create the standard consumer queues:

```bash
FULFILLMENT_QUEUE_URL=$(aws sqs create-queue \
  --queue-name "$FULFILLMENT_QUEUE" \
  --query 'QueueUrl' \
  --output text)

ANALYTICS_QUEUE_URL=$(aws sqs create-queue \
  --queue-name "$ANALYTICS_QUEUE" \
  --query 'QueueUrl' \
  --output text)
```

Create the notifications queue with a redrive policy:

```bash
cat > notifications-queue-attributes.json <<EOF
{
  "RedrivePolicy": "{\"deadLetterTargetArn\":\"${NOTIFICATIONS_DLQ_ARN}\",\"maxReceiveCount\":\"3\"}",
  "VisibilityTimeout": "30",
  "MessageRetentionPeriod": "345600"
}
EOF

NOTIFICATIONS_QUEUE_URL=$(aws sqs create-queue \
  --queue-name "$NOTIFICATIONS_QUEUE" \
  --attributes file://notifications-queue-attributes.json \
  --query 'QueueUrl' \
  --output text)
```

Capture the queue ARNs:

```bash
FULFILLMENT_QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$FULFILLMENT_QUEUE_URL" \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text)

ANALYTICS_QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$ANALYTICS_QUEUE_URL" \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text)

NOTIFICATIONS_QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$NOTIFICATIONS_QUEUE_URL" \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text)
```

## Step 4: Allow SNS to Send Messages to the Queues

Each queue needs a resource policy that allows only your topic to publish to it.

### Fulfillment queue policy

```bash
cat > fulfillment-queue-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSnsPublish",
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "${FULFILLMENT_QUEUE_ARN}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${TOPIC_ARN}"
        }
      }
    }
  ]
}
EOF

aws sqs set-queue-attributes \
  --queue-url "$FULFILLMENT_QUEUE_URL" \
  --attributes Policy="$(jq -c . fulfillment-queue-policy.json)"
```

### Analytics queue policy

```bash
cat > analytics-queue-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSnsPublish",
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "${ANALYTICS_QUEUE_ARN}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${TOPIC_ARN}"
        }
      }
    }
  ]
}
EOF

aws sqs set-queue-attributes \
  --queue-url "$ANALYTICS_QUEUE_URL" \
  --attributes Policy="$(jq -c . analytics-queue-policy.json)"
```

### Notifications queue policy

```bash
cat > notifications-queue-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSnsPublish",
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "${NOTIFICATIONS_QUEUE_ARN}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${TOPIC_ARN}"
        }
      }
    }
  ]
}
EOF

aws sqs set-queue-attributes \
  --queue-url "$NOTIFICATIONS_QUEUE_URL" \
  --attributes Policy="$(jq -c . notifications-queue-policy.json)"
```

## Step 5: Subscribe the Queues to the Topic

```bash
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol sqs \
  --notification-endpoint "$FULFILLMENT_QUEUE_ARN"

aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol sqs \
  --notification-endpoint "$ANALYTICS_QUEUE_ARN"

aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol sqs \
  --notification-endpoint "$NOTIFICATIONS_QUEUE_ARN"
```

Now one published event can reach three independent consumers.

## Step 6: Publish an Order Event

Create a sample order payload:

```bash
cat > order-event.json <<'EOF'
{
  "eventType": "OrderPlaced",
  "orderId": "ORD-1001",
  "customerId": "CUST-42",
  "petType": "corgi",
  "tier": "epic",
  "amountUsd": 19.99,
  "timestamp": "2026-04-22T15:30:00Z"
}
EOF

aws sns publish \
  --topic-arn "$TOPIC_ARN" \
  --message file://order-event.json
```

## Step 7: Consume Messages from Each Queue

Receive the message from fulfillment:

```bash
aws sqs receive-message \
  --queue-url "$FULFILLMENT_QUEUE_URL" \
  --max-number-of-messages 1 \
  --wait-time-seconds 5
```

Receive the message from analytics:

```bash
aws sqs receive-message \
  --queue-url "$ANALYTICS_QUEUE_URL" \
  --max-number-of-messages 1 \
  --wait-time-seconds 5
```

Receive the message from notifications:

```bash
aws sqs receive-message \
  --queue-url "$NOTIFICATIONS_QUEUE_URL" \
  --max-number-of-messages 1 \
  --wait-time-seconds 5 \
  --attribute-names All
```

What to notice:

- the same event reaches multiple consumers
- each queue can be processed at its own pace
- consumers are decoupled from the publisher and from each other

## Step 8: Simulate Successful Processing

When a consumer finishes its work, it deletes the message.

First receive a message and capture the receipt handle from the output.

Then delete it:

```bash
aws sqs delete-message \
  --queue-url "$FULFILLMENT_QUEUE_URL" \
  --receipt-handle <receipt-handle>
```

This models successful asynchronous processing.

## Step 9: Simulate a Failing Consumer and DLQ Behavior

Now treat the `notifications` queue as a failing consumer. Receive the same message repeatedly but do not delete it.

```bash
aws sqs receive-message \
  --queue-url "$NOTIFICATIONS_QUEUE_URL" \
  --max-number-of-messages 1 \
  --wait-time-seconds 5 \
  --attribute-names All
```

Wait for the visibility timeout to expire, then receive it again. Repeat until the `ApproximateReceiveCount` reaches the configured limit.

After enough failed receives, the message should be moved to the DLQ.

Check the main queue:

```bash
aws sqs get-queue-attributes \
  --queue-url "$NOTIFICATIONS_QUEUE_URL" \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible
```

Check the DLQ:

```bash
aws sqs receive-message \
  --queue-url "$NOTIFICATIONS_DLQ_URL" \
  --max-number-of-messages 1 \
  --wait-time-seconds 5 \
  --attribute-names All
```

## Step 10: Publish a Burst of Events

Publish several order events quickly and observe that the queues buffer the burst.

```bash
for i in 1002 1003 1004 1005 1006; do
  aws sns publish \
    --topic-arn "$TOPIC_ARN" \
    --message "{\"eventType\":\"OrderPlaced\",\"orderId\":\"ORD-${i}\",\"customerId\":\"CUST-${i}\",\"petType\":\"gecko\",\"tier\":\"rare\",\"amountUsd\":9.99}"
done
```

Inspect the queue depth:

```bash
aws sqs get-queue-attributes \
  --queue-url "$FULFILLMENT_QUEUE_URL" \
  --attribute-names ApproximateNumberOfMessages
```

This is the buffering effect that helps protect slower consumers.

## What You Should Observe

- one publish can trigger many downstream actions
- consumers do not need to run at the same speed
- failed processing should not lose messages silently
- DLQs isolate problem messages for later inspection
- queue depth is a useful operational signal during bursts

## When to Use SNS vs SQS vs EventBridge

Use SNS when:

- you want straightforward pub/sub fanout
- many consumers should receive the same event
- simple push to SQS, Lambda, or HTTP endpoints is enough

Use SQS when:

- you need buffering
- consumers process at different rates
- retry, visibility timeout, and DLQ behavior matter
- point-to-point or work-queue semantics fit better than broadcast

Use EventBridge when:

- event routing rules need to be richer
- many AWS services produce events natively
- event buses across applications or accounts are useful
- content-based routing matters more than raw fanout simplicity

## Design Takeaways

1. Event-driven architecture reduces coupling between producer and consumer.
2. Queues absorb spikes and protect slower downstream systems.
3. DLQs improve operability by isolating poison messages.
4. Retry settings and visibility timeout are architecture choices, not just implementation details.
5. Fanout is a cleaner pattern than hard-coding downstream integrations into your producer.

## Fun Extensions

1. Add message filtering with SNS subscription filter policies.
2. Add a FIFO queue and compare ordering guarantees.
3. Add an EventBridge bus for richer routing.
4. Add a Lambda consumer for one queue.
5. Add CloudWatch alarms for queue depth and DLQ depth.

## Cleanup

List subscriptions so you can remove them cleanly:

```bash
aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN"
```

Delete each subscription returned:

```bash
aws sns unsubscribe --subscription-arn <subscription-arn>
```

Delete the topic:

```bash
aws sns delete-topic --topic-arn "$TOPIC_ARN"
```

Delete the queues:

```bash
aws sqs delete-queue --queue-url "$FULFILLMENT_QUEUE_URL"
aws sqs delete-queue --queue-url "$ANALYTICS_QUEUE_URL"
aws sqs delete-queue --queue-url "$NOTIFICATIONS_QUEUE_URL"
aws sqs delete-queue --queue-url "$NOTIFICATIONS_DLQ_URL"
```

Delete local files:

```bash
rm -f order-event.json notifications-queue-attributes.json fulfillment-queue-policy.json analytics-queue-policy.json notifications-queue-policy.json
```
