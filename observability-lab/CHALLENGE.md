# Observability Challenge Lab

This challenge extends the observability lab and focuses on the design choices behind operational visibility.

## Challenge 1: Separate Warnings from Errors

Create a second metric filter for `WARN` events.

Questions:

1. Why should warnings and errors usually be monitored separately?
2. When might a high warning rate matter even if errors stay low?

<details>
<summary>Show Solution</summary>

Use a separate metric and threshold because warnings often indicate degraded behavior, not outright failure.

This helps teams:

- spot early trouble
- avoid paging too aggressively
- distinguish signal severity more clearly
</details>

## Challenge 2: Create a Composite Alarm

Imagine you only want to page operators when both error count is high and a queue backlog is growing.

<details>
<summary>Show Solution</summary>

A composite alarm is useful when a single metric is too noisy.

Good use case:

- app errors are elevated
- downstream queue depth is also elevated

This reduces false positives and makes paging more meaningful.
</details>

## Challenge 3: Explain Why CloudTrail Is Not App Telemetry

Why can CloudTrail not replace application logs?

<details>
<summary>Show Solution</summary>

CloudTrail records AWS API activity, not business logic inside your application.

It helps answer:

- who changed a resource
- when an API call happened

It does not explain:

- why an order failed
- what payload caused an application exception
- how a request moved through your service
</details>

## Challenge 4: Design a Better Alarm Threshold

The base lab alarms on one error in one minute. Why might that be too sensitive in production?

<details>
<summary>Show Solution</summary>

One error may be acceptable noise in some systems.

Better production alarm design often considers:

- recent baseline behavior
- error rate, not just raw count
- multiple evaluation periods
- severity and business impact
</details>

## Challenge 5: Add Structured Logging

Redesign the application logs as JSON instead of plain text. What benefits does that create?

<details>
<summary>Show Solution</summary>

Structured logs make it easier to:

- filter by fields like `orderId` or `customerId`
- build more precise metric filters
- support analytics and incident response

This is usually better than fragile free-text parsing.
</details>

## Challenge 6: Alarm Routing Strategy

Explain why all alarms should not necessarily notify the same people in the same way.

<details>
<summary>Show Solution</summary>

Different alarms imply different urgency and ownership.

Examples:

- security alarms may go to a security channel
- application errors may go to service owners
- cost alarms may go to platform or finance stakeholders

Good routing reduces alert fatigue.
</details>

## Stretch Goal

Design a monitoring strategy for a three-tier application with:

- ALB
- app service
- RDS
- async worker queue

List the top metrics, top alarms, and the most useful log sources for each tier.
