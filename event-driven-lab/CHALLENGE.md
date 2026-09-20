# Event-Driven Challenge Lab

This challenge extends the base event-driven lab and focuses on common architecture decisions around routing, retries, and consumer behavior.

## Challenge 1: Add an SNS Filter Policy

Suppose the `notifications` consumer should receive only `epic` orders, not every order.

Questions:

1. Why might you filter at subscription time instead of letting the consumer inspect and ignore messages?
2. What operational benefit does filtering provide?

<details>
<summary>Show Solution</summary>

Use SNS subscription filter policies so the queue receives only relevant messages.

Example idea:

- publish message attributes such as `tier=epic`
- apply a filter policy on the subscription

This reduces:

- queue noise
- useless consumer work
- cost and operational clutter
</details>

## Challenge 2: Add a FIFO Queue

Model a workflow where order events must stay in strict order per customer.

<details>
<summary>Show Solution</summary>

Use an SQS FIFO queue when ordering and deduplication matter.

Tradeoff:

- stronger guarantees
- lower flexibility and sometimes lower throughput than standard queues

This is a good fit for workflows like financial ledgers or strictly ordered account updates.
</details>

## Challenge 3: Tune Visibility Timeout

Your consumer takes about 90 seconds to process a message, but the queue visibility timeout is only 30 seconds. What can go wrong?

<details>
<summary>Show Solution</summary>

If visibility timeout is too short:

- the same message can reappear before processing is complete
- another consumer may pick it up
- you may get duplicate work or inconsistent side effects

Fixes include:

- increasing visibility timeout
- extending visibility during processing
- designing idempotent consumers
</details>

## Challenge 4: Explain the DLQ Boundary

When should a message go to a DLQ versus being retried forever?

<details>
<summary>Show Solution</summary>

DLQs are useful when:

- the message is malformed
- business validation always fails
- repeated retries are unlikely to succeed

Infinite retry is dangerous because:

- it hides persistent failures
- it clogs the main queue
- it delays healthy work
</details>

## Challenge 5: Compare SNS and EventBridge

Explain when you would choose EventBridge instead of SNS for order events.

<details>
<summary>Show Solution</summary>

Choose EventBridge when:

- you want richer routing rules
- many AWS-native producers and targets are involved
- cross-account eventing matters
- event buses are part of the platform design

Choose SNS when:

- you need simple fanout
- the routing model is straightforward
- SQS subscribers are the main pattern
</details>

## Challenge 6: Make the Consumer Idempotent

Describe how you would protect the analytics consumer from counting the same order twice.

<details>
<summary>Show Solution</summary>

An idempotent consumer should detect that an `orderId` has already been processed.

Common techniques:

- store processed event IDs
- use conditional writes in DynamoDB
- use database uniqueness constraints

This matters because at-least-once delivery means duplicates are normal, not exceptional.
</details>

## Stretch Goal

Design a multi-account version:

- one account owns the ordering platform
- another owns analytics
- another owns notifications

Explain whether you would use SNS, EventBridge, or both, and why.
