#!/bin/bash

echo "🎮 Minecraft Analytics Bots Setup"
echo "=================================="
echo ""

# Check if bun is installed
if ! command -v bun &> /dev/null; then
    echo "❌ Bun is not installed!"
    echo ""
    echo "Please install Bun first:"
    echo "curl -fsSL https://bun.sh/install | bash"
    echo ""
    echo "Then restart your terminal and run this setup again."
    exit 1
fi

echo "✅ Bun is installed: $(bun --version)"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
bun install

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully"
else
    echo "❌ Failed to install dependencies"
    exit 1
fi

# Make scripts executable
echo ""
echo "🔧 Making scripts executable..."
chmod +x *.js

echo "✅ Scripts are now executable"

# Check for environment variables
echo ""
echo "🌍 Environment Configuration:"
echo "MINECRAFT_HOST: ${MINECRAFT_HOST:-localhost (default)}"
echo "MINECRAFT_PORT: ${MINECRAFT_PORT:-25565 (default)}"
echo "VERBOSE: ${VERBOSE:-false (default)}"

echo ""
echo "🧪 Testing server connection..."
echo ""

# Test connection
bun run test-connection.js

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Setup completed successfully!"
    echo ""
    echo "🚀 Ready to run bot scenarios:"
    echo "  bun run index.js demo       # Quick demo (3 bots, 10 min)"
    echo "  bun run index.js chat       # Chat-focused bots (5 bots, 15 min)"
    echo "  bun run index.js continuous # Continuous spawning (until stopped)"
    echo "  bun run death-bots.js 3 300 # Death bots (3 bots, 5 min)"
    echo ""
    echo "📖 For more options: bun run index.js help"
else
    echo ""
    echo "⚠️  Setup completed but server connection failed."
    echo ""
    echo "🔧 Before running bots:"
    echo "1. Make sure your Minecraft server is running"
    echo "2. Set server to offline mode (online-mode=false)"
    echo "3. Configure the correct host/port if needed:"
    echo "   export MINECRAFT_HOST=your-server-ip"
    echo "   export MINECRAFT_PORT=25565"
    echo ""
    echo "Then test again: bun run test-connection.js"
fi 