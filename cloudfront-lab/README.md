# CloudFront Edge Delivery Lab

This lab teaches the production-style pattern for serving static content on AWS:

- Amazon S3 as the origin
- Amazon CloudFront as the global CDN
- private S3 access through Origin Access Control (OAC)
- HTTPS at the edge

The goal is to move beyond basic public S3 website hosting and practice the design choices a Solutions Architect would actually make for a real deployment.

## Learning Objectives

By the end of this lab, you should be able to:

- Explain why CloudFront is usually preferred over direct public S3 website hosting
- Create a private S3 bucket for origin content
- Create a CloudFront distribution with an S3 origin
- Restrict direct S3 access so content is only served through CloudFront
- Tune basic cache behavior and invalidations
- Understand where ACM and Route 53 fit when adding a custom domain

## Why This Lab Matters

The simple S3 website lab in this repo is useful for fundamentals, but most production architectures add CloudFront because it provides:

- HTTPS by default
- global edge caching
- better performance for distant users
- tighter origin protection
- optional WAF integration
- cache invalidation and behavior controls

## Cost

This lab is designed to stay inexpensive:

- S3: a tiny bucket with a few text files
- CloudFront: light usage only
- Route 53 and ACM: optional if you do the custom domain extension

If you upload only a few small files and test briefly, the cost should remain very low.

## Architecture

Base architecture:

- private S3 bucket stores static files
- CloudFront distribution serves those files publicly
- OAC signs requests from CloudFront to S3
- bucket policy allows only the CloudFront distribution to read objects

Optional extension:

- ACM certificate in `us-east-1`
- Route 53 alias record for a custom domain like `assets.example.com`

## Prerequisites

- AWS CLI configured with permissions for S3, CloudFront, and IAM-related policy updates on S3
- `jq` installed
- Optional: a Route 53 hosted zone if you want the custom domain section

## Lab Overview

1. Create a private S3 bucket
2. Upload static files
3. Create an Origin Access Control
4. Create a CloudFront distribution
5. Attach a bucket policy that allows only CloudFront to read
6. Test caching and invalidation
7. Optionally add ACM and Route 53 for a custom domain
8. Clean up

## Step 1: Set Variables

```bash
LAB_ID=$(date +%Y%m%d%H%M%S)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)

if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi

BUCKET_NAME="cloudfront-edge-lab-${ACCOUNT_ID}-${LAB_ID}"

echo "Using bucket: $BUCKET_NAME"
echo "Using region: $AWS_REGION"
```

## Step 2: Create a Private S3 Bucket

Create the bucket without static website hosting and keep public access blocked.

```bash
if [ "$AWS_REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false
```

Why this matters:

- S3 stays private
- CloudFront becomes the only public entry point
- you avoid the anti-pattern of exposing your origin bucket directly

## Step 3: Upload Tiny Static Files

Create a minimal site.

```bash
cat > index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>CloudFront Edge Lab</title>
    <style>
      body {
        font-family: Arial, sans-serif;
        max-width: 760px;
        margin: 40px auto;
        padding: 0 16px;
        line-height: 1.6;
      }
      .card {
        padding: 24px;
        border: 1px solid #d0d7de;
        border-radius: 12px;
      }
      code {
        background: #f6f8fa;
        padding: 2px 6px;
        border-radius: 6px;
      }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>CloudFront Edge Lab</h1>
      <p>This content is served from a private S3 bucket through CloudFront.</p>
      <p id="build">Build stamp: initial</p>
    </div>
  </body>
</html>
EOF

printf 'cacheable asset\n' > app.txt

aws s3 cp index.html "s3://${BUCKET_NAME}/index.html"
aws s3 cp app.txt "s3://${BUCKET_NAME}/app.txt"
```

## Step 4: Create an Origin Access Control

CloudFront now prefers Origin Access Control over the older Origin Access Identity pattern.

```bash
cat > oac-config.json <<'EOF'
{
  "Name": "edge-lab-oac",
  "Description": "OAC for CloudFront edge delivery lab",
  "SigningProtocol": "sigv4",
  "SigningBehavior": "always",
  "OriginAccessControlOriginType": "s3"
}
EOF

OAC_ID=$(aws cloudfront create-origin-access-control \
  --origin-access-control-config file://oac-config.json \
  --query 'OriginAccessControl.Id' \
  --output text)

echo "OAC ID: $OAC_ID"
```

## Step 5: Create the CloudFront Distribution

First capture the S3 regional domain name:

```bash
if [ "$AWS_REGION" = "us-east-1" ]; then
  S3_ORIGIN_DOMAIN="${BUCKET_NAME}.s3.amazonaws.com"
else
  S3_ORIGIN_DOMAIN="${BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com"
fi

echo "Origin domain: $S3_ORIGIN_DOMAIN"
```

Create the distribution config:

```bash
cat > distribution-config.json <<EOF
{
  "CallerReference": "edge-lab-${LAB_ID}",
  "Comment": "CloudFront edge delivery lab",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "s3-${BUCKET_NAME}",
        "DomainName": "${S3_ORIGIN_DOMAIN}",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        },
        "OriginAccessControlId": "${OAC_ID}"
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "s3-${BUCKET_NAME}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6"
  },
  "Restrictions": {
    "GeoRestriction": {
      "RestrictionType": "none",
      "Quantity": 0
    }
  },
  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": true
  }
}
EOF

DIST_ID=$(aws cloudfront create-distribution \
  --distribution-config file://distribution-config.json \
  --query 'Distribution.Id' \
  --output text)

DIST_DOMAIN=$(aws cloudfront get-distribution \
  --id "$DIST_ID" \
  --query 'Distribution.DomainName' \
  --output text)

echo "Distribution ID: $DIST_ID"
echo "Distribution domain: $DIST_DOMAIN"
```

CloudFront deployment takes time. Check status until it becomes `Deployed`:

```bash
aws cloudfront get-distribution \
  --id "$DIST_ID" \
  --query 'Distribution.Status' \
  --output text
```

## Step 6: Allow Only CloudFront to Read the Bucket

Now add the bucket policy that grants `s3:GetObject` only to this CloudFront distribution.

```bash
cat > bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${DIST_ID}"
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --policy file://bucket-policy.json
```

Why this works:

- ACL-based public access remains blocked
- the bucket policy is still private because it grants access only to your CloudFront distribution
- CloudFront can read, but anonymous users still cannot

## Step 7: Test the Distribution

Open the site:

```bash
echo "https://${DIST_DOMAIN}"
```

You can also use `curl`:

```bash
curl -I "https://${DIST_DOMAIN}"
curl "https://${DIST_DOMAIN}/app.txt"
```

Try the direct S3 URL too. It should not behave like the public website endpoint because the bucket is private:

```bash
curl -I "https://${S3_ORIGIN_DOMAIN}/index.html"
```

Expected result:

- CloudFront URL works
- direct S3 access is denied

## Step 8: Observe Caching

Fetch the asset a few times and inspect the headers:

```bash
curl -I "https://${DIST_DOMAIN}/app.txt"
```

Look for headers like:

- `x-cache`
- `via`

You will usually see `Miss from cloudfront` first and then `Hit from cloudfront` on later requests.

## Step 9: Update Content and Invalidate

CloudFront caches objects, so changed content may not appear immediately if the path is cached.

Update the file:

```bash
printf 'cacheable asset v2\n' > app.txt
aws s3 cp app.txt "s3://${BUCKET_NAME}/app.txt"
```

Fetch it again. You may still get the old version temporarily.

Create an invalidation:

```bash
aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/app.txt"
```

Re-test:

```bash
curl "https://${DIST_DOMAIN}/app.txt"
```

## Optional: Add a Custom Domain with ACM and Route 53

This section is optional because it adds a little more setup. It is still inexpensive, but it requires a hosted zone you control.

Important note:

- CloudFront viewer certificates must come from ACM in `us-east-1`

### 1. Request the certificate in `us-east-1`

```bash
CUSTOM_DOMAIN="assets.example.com"

CERT_ARN=$(aws acm request-certificate \
  --region us-east-1 \
  --domain-name "$CUSTOM_DOMAIN" \
  --validation-method DNS \
  --query CertificateArn \
  --output text)

echo "$CERT_ARN"
```

### 2. Create the DNS validation record

Fetch the validation details:

```bash
aws acm describe-certificate \
  --region us-east-1 \
  --certificate-arn "$CERT_ARN"
```

Create the returned CNAME in your hosted zone.

### 3. Update the distribution to use aliases and the ACM certificate

You will need to:

- get the current distribution config
- add `Aliases`
- switch the viewer certificate from the default certificate to the ACM cert
- submit the update with the current ETag

This is a good architect exercise because CloudFront updates are config-driven and immutable in-place without the full distribution config.

### 4. Create a Route 53 alias record

Point `assets.example.com` to the CloudFront distribution.

## Design Takeaways

This lab demonstrates a few important architecture choices:

1. S3 can store the content, but CloudFront should usually be the public delivery layer.
2. Keep the origin private and let CloudFront be the only reader.
3. HTTPS and redirect behavior belong at the edge.
4. Caching improves performance but introduces consistency tradeoffs.
5. Invalidations work, but versioned object names are often even better in production.

## Fun Extensions

1. Add a `/images/*` cache behavior with a different cache policy.
2. Add a custom error response for `403` or `404`.
3. Add a WAF web ACL to the distribution.
4. Add signed URLs for a private download area.
5. Compare cost and behavior between invalidations and versioned filenames.

## Cleanup

Delete the invalidations only by waiting for completion; they are not deleted directly.

Disable and delete the distribution:

```bash
aws cloudfront get-distribution-config --id "$DIST_ID"
```

CloudFront deletion requires:

1. get the distribution config and ETag
2. set `Enabled` to `false`
3. update the distribution
4. wait for deployment
5. delete the distribution with the latest ETag

Example workflow:

```bash
aws cloudfront get-distribution-config --id "$DIST_ID" > dist-config-full.json
```

Edit the file so `Enabled` is `false`, then update:

```bash
ETAG=$(jq -r '.ETag' dist-config-full.json)
jq '.DistributionConfig.Enabled = false | .DistributionConfig' dist-config-full.json > dist-config-disabled.json

aws cloudfront update-distribution \
  --id "$DIST_ID" \
  --if-match "$ETAG" \
  --distribution-config file://dist-config-disabled.json
```

Wait until status is `Deployed`, then fetch the new ETag and delete:

```bash
NEW_ETAG=$(aws cloudfront get-distribution-config --id "$DIST_ID" --query 'ETag' --output text)

aws cloudfront delete-distribution \
  --id "$DIST_ID" \
  --if-match "$NEW_ETAG"
```

Delete the OAC:

```bash
aws cloudfront delete-origin-access-control \
  --id "$OAC_ID" \
  --if-match $(aws cloudfront get-origin-access-control --id "$OAC_ID" --query 'ETag' --output text)
```

Delete S3 content and bucket:

```bash
aws s3 rm "s3://${BUCKET_NAME}" --recursive
aws s3api delete-bucket-policy --bucket "$BUCKET_NAME"
aws s3api delete-bucket --bucket "$BUCKET_NAME"
```

Delete local files:

```bash
rm -f index.html app.txt oac-config.json distribution-config.json bucket-policy.json dist-config-full.json dist-config-disabled.json
```
