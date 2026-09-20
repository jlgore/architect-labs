# Redis Caching Example with SST

This is a NextJS application that demonstrates how to use Redis for caching database results. It's built using the SST (Serverless Stack) framework for AWS infrastructure provisioning.

## Features

- **Redis Caching**: Check Redis cache before hitting the database
- **Cache Invalidation**: Ability to clear cache entries on demand
- **SST Integration**: Uses SST for AWS deployment and Redis/Postgres integration
- **Development Mode**: Local Redis implementation for development

## How It Works

1. When a user requests data by ID, the app first checks if that data exists in Redis
2. If found in Redis (cache hit), it returns the cached data immediately
3. If not found (cache miss), it queries the database, returns the result, and updates the cache
4. Cache entries expire after a configurable time (1 hour by default)

## Architecture

The application is structured with:

- NextJS frontend
- API routes for data fetching
- Redis cache integration through SST
- Postgres database integration through SST

## SST Infrastructure

The `sst.config.ts` file defines the AWS resources needed:

```typescript
const vpc = new sst.aws.Vpc("MyVpc");
const redis = new sst.aws.Redis("MyRedis", { vpc });
const database = new sst.aws.Postgres("MyDatabase", { vpc });

new sst.aws.Nextjs("MyWeb", {
  link: [redis, database],
  vpc,
});
```

## Development

In development mode, the application uses an in-memory Redis implementation. When deployed to AWS, it connects to an ElastiCache Redis instance.

To run the application locally:

```bash
npm install
npm run dev
```

## Production Deployment

To deploy the application to AWS:

```bash
npx sst deploy --stage prod
```

## Resources

- [SST Redis Documentation](https://sst.dev/docs/component/aws/redis/)
- [NextJS Documentation](https://nextjs.org/docs)
- [Redis Documentation](https://redis.io/documentation)
