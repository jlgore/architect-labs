# Observability and Operations Lab

This lab teaches core observability patterns for AWS workloads using low-cost services and CLI-first workflows.

The main building blocks are:

- CloudWatch Logs
- CloudWatch custom metrics and metric filters
- CloudWatch alarms
- SNS notifications
- basic CloudTrail event inspection
- optional dashboards

The goal is to show how architects and operators turn raw activity into actionable signals.

## Learning Objectives

By the end of this lab, you should be able to:

- Explain the difference between logs, metrics, alarms, and audit trails
- Create a CloudWatch log group and publish structured events
- Turn log patterns into CloudWatch metrics with metric filters
- Create alarms that notify operators through SNS
- Inspect recent CloudTrail events for operational context
- Understand when dashboards help and when alarms matter more

## Scenario

You are designing observability for `Pixel Pets Orders`, a small backend service.

The service emits application logs like:

- normal order activity
- warnings
- errors

You want to:

- centralize logs
- count errors automatically
- trigger an alert when errors spike
- preserve basic audit visibility for recent control-plane actions

## Why This Lab Matters

A system is not operationally complete just because it deploys successfully.

Architects need to think about:

- how teams will detect trouble
- how fast they can triage issues
- what signals are useful during incidents
- whether there is enough audit visibility to explain changes

## Cost

This lab is designed to stay inexpensive:

- small CloudWatch log volume
- a few custom metric datapoints
- one SNS topic
- no always-on compute required in the base lab

Optional dashboard use is still cheap at this scale.

## Architecture

Base design:

- application writes logs to CloudWatch Logs
- a metric filter turns error lines into a numeric signal
- a CloudWatch alarm evaluates that signal
- SNS notifies operators when the alarm enters alarm state
- CloudTrail event history helps with audit and troubleshooting context

## Prerequisites

- AWS CLI configured with permissions for CloudWatch, Logs, SNS, and CloudTrail lookup
- `jq` installed

## Lab Overview

1. Create an SNS topic for alerts
2. Create a log group and log stream
3. Publish normal and error events
4. Create a metric filter for error detection
5. Create a CloudWatch alarm
6. Force the alarm by publishing more error logs
7. Inspect CloudTrail event history
8. Optionally create a dashboard
9. Clean up

## Step 1: Set Variables

```bash
LAB_ID=$(date +%Y%m%d%H%M%S)
AWS_REGION=$(aws configure get region)

if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi

TOPIC_NAME="pixel-pets-ops-alerts-${LAB_ID}"
LOG_GROUP_NAME="/pixel-pets/orders/${LAB_ID}"
LOG_STREAM_NAME="app"
METRIC_NAMESPACE="PixelPets/Orders"
METRIC_NAME="ErrorCount"
ALARM_NAME="pixel-pets-error-alarm-${LAB_ID}"
DASHBOARD_NAME="pixel-pets-ops-${LAB_ID}"

echo "Using region: $AWS_REGION"
echo "Log group: $LOG_GROUP_NAME"
```

## Step 2: Create an SNS Topic for Alerts

```bash
TOPIC_ARN=$(aws sns create-topic \
  --name "$TOPIC_NAME" \
  --query 'TopicArn' \
  --output text)

echo "Topic ARN: $TOPIC_ARN"
```

Optional: subscribe an email endpoint so you can receive notifications.

```bash
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint you@example.com
```

If you use email, confirm the subscription from your inbox.

## Step 3: Create the Log Group and Stream

```bash
aws logs create-log-group --log-group-name "$LOG_GROUP_NAME"

aws logs create-log-stream \
  --log-group-name "$LOG_GROUP_NAME" \
  --log-stream-name "$LOG_STREAM_NAME"
```

## Step 4: Publish Application Logs

Create a small batch of log events. We will include normal activity and one error.

```bash
NOW_MS=$(($(date +%s) * 1000))
LATER_MS=$((NOW_MS + 1000))
ERROR_MS=$((NOW_MS + 2000))

cat > log-events.json <<EOF
[
  {
    "timestamp": ${NOW_MS},
    "message": "INFO OrderPlaced orderId=ORD-2001 customerId=CUST-10 amount=19.99"
  },
  {
    "timestamp": ${LATER_MS},
    "message": "WARN PaymentRetry orderId=ORD-2001 attempt=2"
  },
  {
    "timestamp": ${ERROR_MS},
    "message": "ERROR InventoryReservationFailed orderId=ORD-2001 reason=stock_timeout"
  }
]
EOF

aws logs put-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --log-stream-name "$LOG_STREAM_NAME" \
  --log-events file://log-events.json
```

Read the logs back:

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --log-stream-name "$LOG_STREAM_NAME"
```

## Step 5: Create a Metric Filter for Errors

Create a filter that increments a metric whenever a log line contains `ERROR`.

```bash
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "ErrorCountFilter" \
  --filter-pattern 'ERROR' \
  --metric-transformations \
    metricName="$METRIC_NAME",metricNamespace="$METRIC_NAMESPACE",metricValue=1
```

Why this matters:

- logs are detailed but noisy
- metrics are easier to alarm on
- metric filters bridge raw log data to operational signals

## Step 6: Publish More Error Events

Metric filters evaluate new log events after the filter exists, so publish another batch.

```bash
E1_MS=$(($(date +%s) * 1000))
E2_MS=$((E1_MS + 1000))

cat > error-batch.json <<EOF
[
  {
    "timestamp": ${E1_MS},
    "message": "ERROR PaymentProcessorTimeout orderId=ORD-2002"
  },
  {
    "timestamp": ${E2_MS},
    "message": "ERROR FulfillmentDispatchFailed orderId=ORD-2003"
  }
]
EOF

aws logs put-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --log-stream-name "$LOG_STREAM_NAME" \
  --log-events file://error-batch.json
```

Wait a short time, then inspect metric datapoints:

```bash
START_TIME=$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

aws cloudwatch get-metric-statistics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum
```

## Step 7: Create a CloudWatch Alarm

Create an alarm that triggers if error count is `>= 1` in a 1-minute evaluation period.

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Pixel Pets order service error alarm" \
  --metric-name "$METRIC_NAME" \
  --namespace "$METRIC_NAMESPACE" \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN"
```

Check alarm state:

```bash
aws cloudwatch describe-alarms --alarm-names "$ALARM_NAME"
```

If the recent error logs were ingested into the metric period, the alarm should move into `ALARM`.

## Step 8: Manually Force the Alarm State

For fast testing, you can set the alarm state manually.

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "$ALARM_NAME" \
  --state-value ALARM \
  --state-reason "Manual test of notification flow"
```

Why this is useful:

- it tests the notification path quickly
- it lets teams verify alarm wiring during setup
- it is a good operator workflow before relying on real incidents

## Step 9: Inspect CloudTrail Event History

CloudTrail event history gives recent control-plane visibility without extra setup.

Look up recent log-related API actions:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=logs.amazonaws.com \
  --max-results 10
```

Try looking up CloudWatch alarm actions too:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=monitoring.amazonaws.com \
  --max-results 10
```

What this shows:

- who made recent changes
- which API actions happened
- when operational changes occurred

This is not the same as application observability, but it is important operational context.

## Step 10: Optional Dashboard

Create a simple dashboard that shows the error metric and the alarm.

```bash
cat > dashboard-body.json <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Pixel Pets Error Count",
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "metrics": [
          [ "${METRIC_NAMESPACE}", "${METRIC_NAME}" ]
        ],
        "period": 60,
        "stat": "Sum"
      }
    },
    {
      "type": "alarm",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Alarm State",
        "alarms": [
          "arn:aws:cloudwatch:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):alarm:${ALARM_NAME}"
        ]
      }
    }
  ]
}
EOF

aws cloudwatch put-dashboard \
  --dashboard-name "$DASHBOARD_NAME" \
  --dashboard-body file://dashboard-body.json
```

Why dashboards help:

- they give shared visual context
- they help during incident calls
- they are useful, but alarms still matter more for active detection

## Logs vs Metrics vs Alarms vs CloudTrail

Use logs when:

- you need detailed event context
- you are debugging a specific request or failure

Use metrics when:

- you need a compact signal over time
- you want trend or threshold analysis

Use alarms when:

- you need notification or automated action
- an operator should be paged or informed

Use CloudTrail when:

- you need AWS API audit visibility
- you want to understand who changed infrastructure or control-plane settings

## What You Should Observe

- raw logs become much more useful once converted into metrics
- alarms are about response, not just measurement
- CloudTrail helps explain operational changes, not app-level business flow
- dashboards support humans, but alarms drive action

## Design Takeaways

1. Good observability starts with useful signals, not just data collection.
2. Metric filters are a simple way to turn application errors into alarms.
3. Audit visibility and application telemetry solve different problems.
4. Manual alarm-state testing is a valid operational practice.
5. Dashboards are valuable, but they do not replace alerting and runbooks.

## Fun Extensions

1. Add a metric filter for `WARN` and compare it with `ERROR`.
2. Create a composite alarm that triggers only when two signals are bad.
3. Add a second log stream to represent another service instance.
4. Emit JSON logs and design richer filter patterns.
5. Add an EventBridge rule that reacts to alarm state changes.

## Cleanup

Delete the dashboard:

```bash
aws cloudwatch delete-dashboards --dashboard-names "$DASHBOARD_NAME"
```

Delete the alarm:

```bash
aws cloudwatch delete-alarms --alarm-names "$ALARM_NAME"
```

Delete the metric filter:

```bash
aws logs delete-metric-filter \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "ErrorCountFilter"
```

Delete the log group:

```bash
aws logs delete-log-group --log-group-name "$LOG_GROUP_NAME"
```

Delete the SNS topic:

```bash
aws sns delete-topic --topic-arn "$TOPIC_ARN"
```

Delete local files:

```bash
rm -f log-events.json error-batch.json dashboard-body.json
```
