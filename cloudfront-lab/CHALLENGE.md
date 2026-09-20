# CloudFront Challenge Lab

This challenge extends the base CloudFront lab and focuses on the tradeoffs that matter in real architectures.

## Challenge 1: Add a Second Cache Behavior

Create a behavior for `/images/*` with a longer cache lifetime than the default behavior.

Questions:

1. Why might image assets get a longer TTL than `index.html`?
2. What risk appears if you cache HTML too aggressively?

<details>
<summary>Show Solution</summary>

The pattern is:

- keep `index.html` relatively fresh
- cache static assets longer
- use versioned asset names for efficient cache busting

In CloudFront, add an ordered cache behavior for `/images/*` using a more cache-friendly policy than the default HTML path.

Architecture takeaway:

- different content types often need different cache strategies
</details>

## Challenge 2: Use Versioned Filenames Instead of Invalidations

Instead of updating `app.txt`, upload `app.v2.txt` and reference the new path.

<details>
<summary>Show Solution</summary>

Upload the new object:

```bash
printf 'cacheable asset version 2\n' > app.v2.txt
aws s3 cp app.v2.txt s3://<bucket-name>/app.v2.txt
```

Then update `index.html` to reference the new path.

Why this is often better:

- avoids waiting for invalidations
- fits CI/CD pipelines well
- makes rollbacks easier
</details>

## Challenge 3: Restrict Methods

Confirm that your distribution allows only `GET` and `HEAD`. Explain why this is a safer default for static content.

<details>
<summary>Show Solution</summary>

Static sites rarely need `POST`, `PUT`, `PATCH`, or `DELETE`.

Restricting methods:

- reduces attack surface
- reflects least privilege at the edge
- makes the distribution behavior clearer to operators
</details>

## Challenge 4: Add a Custom Error Response

Configure CloudFront so that missing objects return a friendlier page.

<details>
<summary>Show Solution</summary>

Add an error page such as `errors/404.html` to S3 and configure a custom error response in the distribution.

This is useful for:

- branded error handling
- SPAs that route client-side
- cleaner user experience
</details>

## Challenge 5: Add WAF Conceptually

You do not need to deploy WAF for this challenge, but explain when you would attach AWS WAF to a CloudFront distribution.

<details>
<summary>Show Solution</summary>

Good reasons include:

- blocking common web exploits
- rate limiting abusive traffic
- geo restrictions or IP reputation filtering
- protecting dynamic origins that sit behind CloudFront

CloudFront plus WAF is a common edge security pattern.
</details>

## Challenge 6: Custom Domain Walkthrough

Explain the full flow for moving from the default CloudFront domain to `assets.example.com`.

<details>
<summary>Show Solution</summary>

The sequence is:

1. Request ACM cert in `us-east-1`
2. Validate it with DNS
3. Update the distribution aliases and viewer certificate
4. Create Route 53 alias record to the distribution

Important detail:

- CloudFront requires ACM certificates in `us-east-1`, even if your S3 bucket is elsewhere
</details>

## Stretch Goal

Design a secure private-download variant of this lab with:

- private bucket
- CloudFront signed URLs or signed cookies
- short-lived access for premium content

This is a strong follow-on architecture pattern for media, software downloads, or partner portals.
