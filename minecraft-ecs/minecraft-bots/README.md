# Minecraft Analytics Bots

This project provides automated Minecraft bots using PrismarineJS and Bun to generate realistic test data for your Minecraft analytics data pipeline. The bots simulate various player behaviors including chatting, movement, deaths, and other activities that will show up in your AWS analytics dashboard.

## 🎯 Purpose

These bots are designed to:
- Generate realistic Minecraft server logs for testing the data pipeline
- Create player activity data (logins, logouts, chat messages, deaths)
- Simulate network traffic for VPC Flow Log analysis
- Provide consistent test data for validating analytics queries
- Demonstrate the data pipeline capabilities with meaningful metrics

## 🚀 Quick Start

### Prerequisites

1. **Bun runtime** installed on your system
2. **Minecraft server** running and accessible
3. **Server in offline mode** (for bot authentication)

### Installation

```bash
# Navigate to the bots directory
cd minecraft-ecs/minecraft-bots

# Install dependencies
bun install

# Make scripts executable
chmod +x *.js
```

### Basic Usage

```bash
# Run a demo scenario (3 bots for 10 minutes)
bun run index.js demo

# Run continuous bot spawning
MINECRAFT_HOST=your-server-ip bun run index.js continuous

# Run death bots to generate death statistics
bun run death-bots.js 5 300  # 5 bots for 5 minutes
```

## 📋 Available Scenarios

### 1. Demo Scenario
```bash
bun run index.js demo
```
- **Duration**: 10 minutes
- **Bots**: 3 bots with normal behavior
- **Purpose**: Quick demonstration of bot capabilities
- **Activities**: Chat, movement, jumping

### 2. Chat Scenario
```bash
bun run index.js chat
```
- **Duration**: 15 minutes
- **Bots**: 5 chatty bots
- **Purpose**: Generate lots of chat message logs
- **Activities**: Frequent chatting, social interactions

### 3. Explorer Scenario
```bash
bun run index.js explorer
```
- **Duration**: 20 minutes
- **Bots**: 4 explorer bots
- **Purpose**: Generate movement and pathfinding logs
- **Activities**: Constant movement, exploration, jumping

### 4. Mixed Scenario
```bash
bun run index.js mixed
```
- **Duration**: 30 minutes
- **Bots**: 6 bots with varied behaviors
- **Purpose**: Realistic mix of player types
- **Activities**: Combination of all behaviors

### 5. Stress Test Scenario
```bash
bun run index.js stress
```
- **Duration**: Variable (5 waves)
- **Bots**: Increasing waves (2, 4, 6, 8, 10 bots)
- **Purpose**: Test server performance and generate high-volume logs
- **Activities**: Rapid connect/disconnect cycles

### 6. Continuous Scenario
```bash
bun run index.js continuous
```
- **Duration**: Until stopped (Ctrl+C)
- **Bots**: Maintains 5 active bots
- **Purpose**: Long-term data generation
- **Activities**: Continuous bot spawning and activity

### 7. Death Bots (Specialized)
```bash
bun run death-bots.js [count] [duration]
```
- **Duration**: Configurable (default: 10 minutes)
- **Bots**: Configurable (default: 3)
- **Purpose**: Generate death statistics for analytics
- **Activities**: Intentional death scenarios (fall, lava, drowning, etc.)

## ⚙️ Configuration

### Environment Variables

```bash
# Server connection
export MINECRAFT_HOST=your-server-ip    # Default: localhost
export MINECRAFT_PORT=25565             # Default: 25565
export VERBOSE=true                     # Enable detailed logging

# Example with custom server
MINECRAFT_HOST=minecraft.example.com MINECRAFT_PORT=25565 bun run index.js demo
```

### Bot Behaviors

The bots support different behavior types:

- **normal**: Balanced chat, movement, and jumping
- **chatty**: Frequent chat messages and social interaction
- **explorer**: Constant movement and exploration
- **death**: Specialized bots that intentionally die

### Customizing Bot Names

Bot names follow patterns defined in `config.js`:
- TestBot_001, TestBot_002, etc.
- AnalyticsBot_001, DataBot_002, etc.
- DeathBot_001 (for death scenarios)

## 📊 Generated Analytics Data

The bots will generate data that appears in your analytics pipeline:

### Player Statistics
- **Login/Logout Events**: Bot connections and disconnections
- **Chat Messages**: Realistic chat conversations
- **Death Events**: Various death scenarios and causes
- **Session Duration**: Varied session lengths
- **Player Engagement**: Message frequency and activity patterns

### Network Statistics
- **Connection Patterns**: Multiple IP connections (if running from different machines)
- **Traffic Volume**: Minecraft protocol traffic on port 25565
- **Session Analytics**: Connection duration and frequency
- **Geographic Distribution**: IP-based location analysis

### Server Statistics
- **Concurrent Players**: Peak and average player counts
- **Server Load**: Connection handling and performance
- **Activity Patterns**: Hourly and daily usage trends
- **Event Distribution**: Types and frequency of server events

## 🔍 Monitoring Bot Activity

### Real-time Statistics

All scenarios provide real-time statistics:

```
📊 Current Statistics:
   Active Bots: 3/5
   Total Messages: 47
   Total Deaths: 12
   Total Moves: 156

🤖 Bot Details:
   🟢 TestBot_001 (normal) - 5m uptime, 12 msgs, 2 deaths
   🟢 AnalyticsBot_002 (chatty) - 4m uptime, 23 msgs, 0 deaths
   🔴 DataBot_003 (explorer) - 3m uptime, 8 msgs, 1 deaths
```

### Log Output

Bots provide detailed logging:
- Connection events (login/logout)
- Chat messages sent and received
- Movement and pathfinding actions
- Death events and respawning
- Error handling and reconnection

## 🎮 Integration with Analytics Pipeline

### Data Flow

1. **Bots Connect** → Minecraft Server logs player joins
2. **Bots Chat** → Server logs chat messages
3. **Bots Move** → Server logs player movement
4. **Bots Die** → Server logs death events
5. **Logs Stream** → CloudWatch → Kinesis Firehose → S3
6. **Glue Jobs Process** → Analytics data in Athena
7. **Query Results** → Player statistics and insights

### Expected Analytics Results

After running bots, you should see:

```sql
-- Player death statistics
SELECT player_name, death_count, login_count
FROM player_statistics
WHERE player_name LIKE '%Bot%'
ORDER BY death_count DESC;

-- Hourly activity patterns
SELECT hour, COUNT(*) as events
FROM minecraft_events
WHERE player_name LIKE '%Bot%'
GROUP BY hour;

-- Network traffic from bots
SELECT srcaddr, connection_count, total_bytes
FROM connection_statistics
WHERE traffic_type = 'minecraft';
```

## 🛠️ Troubleshooting

### Common Issues

1. **Connection Refused**
   ```
   Error: connect ECONNREFUSED
   ```
   - Check if Minecraft server is running
   - Verify host and port configuration
   - Ensure server allows offline mode connections

2. **Authentication Failed**
   ```
   Error: Failed to verify username
   ```
   - Ensure server is in offline mode
   - Check server.properties: `online-mode=false`

3. **Too Many Connections**
   ```
   Error: Connection limit exceeded
   ```
   - Reduce number of concurrent bots
   - Increase server max-players setting
   - Stagger bot connection timing

4. **Bots Not Moving**
   ```
   Pathfinding errors
   ```
   - Server may have spawn protection
   - Bots need time to load world chunks
   - Check server difficulty settings

### Debug Mode

Enable verbose logging:
```bash
VERBOSE=true bun run index.js demo
```

### Server Requirements

For optimal bot performance:
- **Minecraft Server 1.21.4** (or compatible version)
- **Offline mode enabled** (`online-mode=false`)
- **Sufficient player slots** (recommend 20+ for stress testing)
- **Reasonable view distance** (8-16 chunks)

## 📈 Analytics Dashboard Queries

Once bots have generated data, try these Athena queries:

### Bot Activity Summary
```sql
SELECT 
    player_name,
    death_count,
    login_count,
    chat_message_count,
    CASE 
        WHEN login_count > 0 THEN death_count::DOUBLE / login_count 
        ELSE 0 
    END as deaths_per_session
FROM player_statistics
WHERE player_name LIKE '%Bot%'
ORDER BY death_count DESC;
```

### Hourly Bot Activity
```sql
SELECT 
    hour,
    COUNT(DISTINCT player_name) as unique_bots,
    COUNT(*) as total_events
FROM minecraft_events
WHERE player_name LIKE '%Bot%'
GROUP BY hour
ORDER BY hour;
```

### Network Traffic from Bots
```sql
SELECT 
    srcaddr,
    connection_count,
    total_packets,
    total_bytes,
    success_rate
FROM connection_statistics
WHERE traffic_type = 'minecraft'
ORDER BY connection_count DESC;
```

## 🎯 Best Practices

### For Testing
- Start with the **demo** scenario to verify connectivity
- Use **continuous** scenario for long-term data generation
- Run **death-bots** specifically to test death analytics
- Use **stress** scenario to test pipeline performance

### For Production Demo
- Run **mixed** scenario for realistic player simulation
- Use multiple machines for geographic distribution
- Vary timing to create realistic usage patterns
- Monitor server performance during bot activity

### Data Pipeline Validation
- Wait 1-2 hours after bot activity for Glue jobs to process
- Check S3 buckets for raw and processed data
- Verify Athena tables are populated
- Run sample queries to validate analytics

This bot system provides a comprehensive way to generate realistic test data for your Minecraft analytics pipeline, allowing you to demonstrate the full capabilities of your AWS data engineering solution! 