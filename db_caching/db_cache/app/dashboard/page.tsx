"use client";

import { useState } from "react";

export default function Dashboard() {
  const [id, setId] = useState("");
  const [result, setResult] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [initMessage, setInitMessage] = useState("");

  const fetchData = async () => {
    if (!id.trim()) {
      setError("Please enter an ID");
      return;
    }

    setLoading(true);
    setError("");
    try {
      const response = await fetch(`/api/data?id=${encodeURIComponent(id)}`);
      const data = await response.json();
      
      if (response.ok) {
        setResult(data);
      } else {
        setError(data.error || "Failed to fetch data");
        setResult(null);
      }
    } catch (err) {
      setError("An error occurred while fetching data");
      setResult(null);
    } finally {
      setLoading(false);
    }
  };

  const invalidateCache = async () => {
    if (!id.trim()) {
      setError("Please enter an ID");
      return;
    }

    setLoading(true);
    setError("");
    try {
      const response = await fetch("/api/data", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ id }),
      });
      
      const data = await response.json();
      
      if (response.ok) {
        // After invalidating cache, fetch the fresh data
        await fetchData();
      } else {
        setError(data.error || "Failed to invalidate cache");
      }
    } catch (err) {
      setError("An error occurred while invalidating cache");
    } finally {
      setLoading(false);
    }
  };

  const initializeDatabase = async () => {
    setLoading(true);
    setInitMessage("");
    try {
      const response = await fetch("/api/init");
      const data = await response.json();
      
      if (response.ok && data.success) {
        setInitMessage("Database initialized successfully!");
      } else {
        setInitMessage("Failed to initialize database: " + (data.message || "Unknown error"));
      }
    } catch (err) {
      setInitMessage("Error connecting to database initialization endpoint");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto p-6 bg-white text-black">
      <h1 className="text-2xl font-bold mb-6 text-black">Redis Cache Demo with SST</h1>
      
      <div className="mb-8 p-6 bg-white rounded-lg shadow border border-gray-200">
        <div className="flex gap-4 mb-4">
          <input
            type="text"
            value={id}
            onChange={(e) => setId(e.target.value)}
            placeholder="Enter ID to search"
            className="flex-1 px-4 py-2 border rounded focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white text-black"
          />
          <button
            onClick={fetchData}
            disabled={loading}
            className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:opacity-50"
          >
            {loading ? "Loading..." : "Search"}
          </button>
          <button
            onClick={invalidateCache}
            disabled={loading}
            className="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600 disabled:opacity-50"
          >
            Clear Cache
          </button>
        </div>
        
        {error && (
          <div className="p-4 mb-4 bg-red-100 text-red-700 rounded">
            {error}
          </div>
        )}
        
        {result && (
          <div className="mt-6">
            <div className="mb-2 flex items-center">
              <span className="font-semibold mr-2 text-black">Source:</span> 
              <span className={`px-2 py-1 rounded text-sm ${
                result.source === "cache" 
                  ? "bg-green-100 text-green-800" 
                  : "bg-blue-100 text-blue-800"
              }`}>
                {result.source === "cache" ? "Redis Cache" : "Database"}
              </span>
            </div>
            
            <div className="p-4 bg-white rounded border border-gray-200">
              <pre className="whitespace-pre-wrap text-black">
                {JSON.stringify(result.data, null, 2)}
              </pre>
            </div>
            
            <p className="text-sm text-gray-700 mt-2">
              {result.source === "cache" 
                ? "Data was retrieved from Redis cache (fast)" 
                : "Data was retrieved from the database (slower) and cached in Redis for future requests"}
            </p>
          </div>
        )}
      </div>
      
      <div className="bg-white p-4 rounded border border-gray-200 mb-6">
        <h2 className="font-semibold text-lg mb-2 text-black">Database Initialization</h2>
        <p className="mb-4 text-black">If this is your first time using the app, you'll need to initialize the database table:</p>
        
        <div className="flex flex-col gap-2">
          <button
            onClick={initializeDatabase}
            disabled={loading}
            className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 disabled:opacity-50 w-full md:w-auto"
          >
            Initialize Database
          </button>
          
          {initMessage && (
            <div className={`p-2 mt-2 rounded text-sm ${initMessage.includes("successfully") ? "bg-green-100 text-green-800" : "bg-yellow-100 text-yellow-800"}`}>
              {initMessage}
            </div>
          )}
        </div>
      </div>
      
      <div className="bg-white p-4 rounded border border-gray-200 mb-6">
        <h2 className="font-semibold text-lg mb-2 text-black">How it works</h2>
        <ol className="list-decimal pl-5 space-y-2 text-black">
          <li>Enter an ID and click "Search"</li>
          <li>The app first checks if the data exists in Redis cache</li>
          <li>If found in cache, it returns the cached data (fast)</li>
          <li>If not found, it fetches from the Postgres database and updates the cache</li>
          <li>Click "Clear Cache" to invalidate the cache for this ID and force a database lookup</li>
        </ol>
      </div>
      
      <div className="bg-white p-4 rounded border border-gray-200">
        <h2 className="font-semibold text-lg mb-2 text-black">About SST Redis and Postgres Integration</h2>
        <p className="mb-3 text-black">
          This application uses <a href="https://sst.dev/docs/component/aws/redis/" className="text-blue-600 hover:underline" target="_blank" rel="noopener noreferrer">SST Redis</a> and <a href="https://sst.dev/docs/linking/" className="text-blue-600 hover:underline" target="_blank" rel="noopener noreferrer">Resource Linking</a> to connect to AWS infrastructure.
        </p>
        <div className="bg-white p-3 rounded border border-gray-200 mb-3">
          <pre className="text-xs overflow-x-auto text-black">
{`// In sst.config.ts
const vpc = new sst.aws.Vpc("MyVpc");
const redis = new sst.aws.Redis("MyRedis", { vpc });
const database = new sst.aws.Postgres("MyDatabase", { vpc });

new sst.aws.Nextjs("MyWeb", {
  link: [redis, database],
  vpc,
});`}
          </pre>
        </div>
        <p className="mb-3 text-black">
          SST Resource Linking allows our application to access infrastructure securely in our runtime code. The linked resources are injected into our application and we can access them using the SST SDK.
        </p>
        <div className="bg-white p-3 rounded border border-gray-200 mb-3">
          <pre className="text-xs overflow-x-auto text-black">
{`// Access linked resources in code
import { Resource } from "sst";

// Connect to Postgres
const pool = new Pool({
  host: Resource.MyDatabase.host,
  port: Resource.MyDatabase.port,
  user: Resource.MyDatabase.username,
  password: Resource.MyDatabase.password,
  database: Resource.MyDatabase.defaultDatabaseName
});

// Connect to Redis
const redis = new Cluster([{
  host: Resource.MyRedis.host,
  port: Resource.MyRedis.port
}], {
  redisOptions: {
    username: Resource.MyRedis.username,
    password: Resource.MyRedis.password
  }
});`}
          </pre>
        </div>
      </div>
    </div>
  );
} 