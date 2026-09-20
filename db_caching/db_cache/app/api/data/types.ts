// SST Redis declarations
declare module "sst/node/redis" {
  export interface Redis {
    MyRedis: {
      host: string;
      port: number;
      username: string;
      password: string;
    };
  }
  
  export const Redis: Redis;
}

// SST Postgres declarations
declare module "sst/node/postgres" {
  export interface Postgres {
    MyDatabase: {
      host: string;
      port: number;
      username: string;
      password: string;
      defaultDatabaseName: string;
    };
  }
  
  export const Postgres: Postgres;
}

// SST Resource declarations
declare module "sst" {
  export interface Resource {
    MyRedis: {
      host: string;
      port: number;
      username: string;
      password: string;
    };
    MyDatabase: {
      host: string;
      port: number;
      username: string;
      password: string;
      defaultDatabaseName: string;
    };
  }
  
  export const Resource: Resource;
} 