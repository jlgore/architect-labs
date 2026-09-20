import { NextResponse } from "next/server";
import { initDatabase } from "../../lib/db";

// One-time database initialization endpoint
export async function GET() {
  try {
    await initDatabase();
    return NextResponse.json({ 
      success: true, 
      message: "Database initialized successfully" 
    });
  } catch (error) {
    console.error("Error initializing database:", error);
    return NextResponse.json({ 
      success: false, 
      message: "Failed to initialize database" 
    }, { status: 500 });
  }
} 