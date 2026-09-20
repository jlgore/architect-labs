import { NextRequest, NextResponse } from "next/server";
// Import types from our local definitions
import "../../api/data/types";
import { Cluster } from "ioredis";
import { getItem } from "../../lib/db";
import { Resource } from "sst";

// Create a Redis client using SST Resource
const redisClient = new Cluster(
  [{
    host: Resource.MyRedis.host,
    port: Resource.MyRedis.port
  }],
  {
    redisOptions: {
      tls: { checkServerIdentity: () => undefined },
      username: Resource.MyRedis.username,
      password: Resource.MyRedis.password
    },
    // Add explicit cluster options with retries
    clusterRetryStrategy: (times) => {
      // Retry with exponential backoff
      return Math.min(100 + times * 50, 2000);
    }
  }
);

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const id = searchParams.get("id");

  if (!id) {
    return NextResponse.json({ error: "ID parameter is required" }, { status: 400 });
  }

  try {
    // Check if data exists in cache
    const cacheKey = `data:${id}`;
    let cachedData = null;
    
    try {
      cachedData = await redisClient.get(cacheKey);
    } catch (error) {
      console.error("Error accessing Redis cache:", error);
      // Continue without cache if there's an error
    }
    
    if (cachedData) {
      console.log("Cache hit for:", id);
      return NextResponse.json({ 
        data: JSON.parse(cachedData),
        source: "cache" 
      });
    }
    
    // Cache miss, fetch from database
    console.log("Cache miss for:", id);
    const data = await getItem(id);
    
    // Update cache with new data (expire after 1 hour)
    try {
      await redisClient.set(cacheKey, JSON.stringify(data), 'EX', 3600);
    } catch (error) {
      console.error("Error updating Redis cache:", error);
      // Continue even if cache update fails
    }
    
    return NextResponse.json({ 
      data,
      source: "database" 
    });
  } catch (error) {
    console.error("Error fetching data:", error);
    return NextResponse.json({ error: "Failed to fetch data" }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { id } = body;
    
    if (!id) {
      return NextResponse.json({ error: "ID is required" }, { status: 400 });
    }
    
    // Delete from cache to force refresh
    const cacheKey = `data:${id}`;
    try {
      await redisClient.del(cacheKey);
    } catch (error) {
      console.error("Error clearing Redis cache:", error);
      // Continue even if cache clear fails
    }
    
    return NextResponse.json({ 
      success: true,
      message: "Cache invalidated" 
    });
  } catch (error) {
    console.error("Error invalidating cache:", error);
    return NextResponse.json({ error: "Failed to invalidate cache" }, { status: 500 });
  }
} 