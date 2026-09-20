/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    return {
      name: "dbcache",
      removal: input?.stage === "production" ? "retain" : "remove",
      protect: ["production"].includes(input?.stage),
      home: "aws",
    };
  },
  async run() {
    const vpc = new sst.aws.Vpc("MyVpc");
    const redis = new sst.aws.Redis("MyRedis", { vpc });
    const database = new sst.aws.Postgres("MyDatabase", { vpc });

    new sst.aws.Nextjs("MyWeb", {
      link: [redis, database],
      vpc,
    });
  },
});
