#!/usr/bin/env bun

import { BotManager } from './bot-manager.js';
import { config } from './config.js';

// Main bot orchestrator
class MinecraftBotOrchestrator {
  constructor() {
    this.botManager = new BotManager();
    this.scenarios = {
      'demo': this.runDemoScenario.bind(this),
      'stress': this.runStressTestScenario.bind(this),
      'chat': this.runChatScenario.bind(this),
      'explorer': this.runExplorerScenario.bind(this),
      'mixed': this.runMixedScenario.bind(this),
      'continuous': this.runContinuousScenario.bind(this)
    };
  }

  // Demo scenario - a few bots with normal behavior
  async runDemoScenario() {
    console.log('🎮 Starting Demo Scenario');
    console.log('Creating 3 bots with normal behavior for 10 minutes...');
    
    await this.botManager.createMultipleBots(3, ['normal']);
    
    // Show stats every 30 seconds
    const statsInterval = setInterval(() => {
      this.showStats();
    }, 30000);
    
    // Run for 10 minutes
    setTimeout(() => {
      clearInterval(statsInterval);
      this.botManager.disconnectAll();
      console.log('✅ Demo scenario completed');
    }, 600000);
  }

  // Stress test scenario - many bots connecting and disconnecting
  async runStressTestScenario() {
    console.log('🔥 Starting Stress Test Scenario');
    console.log('Creating waves of bots to stress test the server...');
    
    let wave = 1;
    const maxWaves = 5;
    
    const createWave = async () => {
      if (wave > maxWaves) {
        console.log('✅ Stress test completed');
        return;
      }
      
      console.log(`🌊 Wave ${wave}: Creating ${wave * 2} bots`);
      await this.botManager.createMultipleBots(wave * 2, ['normal', 'chatty']);
      
      // Wait 2 minutes, then disconnect all and start next wave
      setTimeout(() => {
        this.botManager.disconnectAll();
        wave++;
        setTimeout(createWave, 30000); // 30 second break between waves
      }, 120000);
    };
    
    createWave();
  }

  // Chat scenario - bots that focus on chatting
  async runChatScenario() {
    console.log('💬 Starting Chat Scenario');
    console.log('Creating chatty bots to generate chat logs...');
    
    await this.botManager.createMultipleBots(5, ['chatty']);
    
    // Show stats every 15 seconds
    const statsInterval = setInterval(() => {
      this.showStats();
    }, 15000);
    
    // Run for 15 minutes
    setTimeout(() => {
      clearInterval(statsInterval);
      this.botManager.disconnectAll();
      console.log('✅ Chat scenario completed');
    }, 900000);
  }

  // Explorer scenario - bots that move around a lot
  async runExplorerScenario() {
    console.log('🗺️ Starting Explorer Scenario');
    console.log('Creating explorer bots to generate movement logs...');
    
    await this.botManager.createMultipleBots(4, ['explorer']);
    
    // Show stats every 30 seconds
    const statsInterval = setInterval(() => {
      this.showStats();
    }, 30000);
    
    // Run for 20 minutes
    setTimeout(() => {
      clearInterval(statsInterval);
      this.botManager.disconnectAll();
      console.log('✅ Explorer scenario completed');
    }, 1200000);
  }

  // Mixed scenario - different types of bots
  async runMixedScenario() {
    console.log('🎭 Starting Mixed Scenario');
    console.log('Creating a mix of different bot behaviors...');
    
    await this.botManager.createMultipleBots(6, ['normal', 'chatty', 'explorer']);
    
    // Show stats every 45 seconds
    const statsInterval = setInterval(() => {
      this.showStats();
    }, 45000);
    
    // Run for 30 minutes
    setTimeout(() => {
      clearInterval(statsInterval);
      this.botManager.disconnectAll();
      console.log('✅ Mixed scenario completed');
    }, 1800000);
  }

  // Continuous scenario - keeps running until stopped
  async runContinuousScenario() {
    console.log('♾️ Starting Continuous Scenario');
    console.log('Running continuous bot spawning. Press Ctrl+C to stop...');
    
    // Start with initial bots
    await this.botManager.createMultipleBots(3, ['normal', 'chatty', 'explorer']);
    
    // Start continuous spawning
    this.botManager.startContinuousSpawning(5, ['normal', 'chatty', 'explorer']);
    
    // Show stats every minute
    const statsInterval = setInterval(() => {
      this.showStats();
    }, 60000);
    
    // Handle graceful shutdown
    process.on('SIGINT', () => {
      console.log('\n🛑 Shutting down...');
      clearInterval(statsInterval);
      this.botManager.disconnectAll();
      process.exit(0);
    });
  }

  // Show current statistics
  showStats() {
    const stats = this.botManager.getStats();
    console.log('\n📊 Current Statistics:');
    console.log(`   Active Bots: ${stats.activeBots}/${stats.totalBots}`);
    console.log(`   Total Messages: ${stats.totalMessages}`);
    console.log(`   Total Deaths: ${stats.totalDeaths}`);
    console.log(`   Total Moves: ${stats.totalMoves}`);
    
    if (stats.bots.length > 0) {
      console.log('\n🤖 Bot Details:');
      stats.bots.forEach(bot => {
        const uptimeMin = Math.floor(bot.uptime / 60000);
        const status = bot.connected ? '🟢' : '🔴';
        console.log(`   ${status} ${bot.name} (${bot.behavior}) - ${uptimeMin}m uptime, ${bot.stats.messagesSpoken} msgs, ${bot.stats.deaths} deaths`);
      });
    }
    console.log('');
  }

  // Run a specific scenario
  async runScenario(scenarioName) {
    if (!this.scenarios[scenarioName]) {
      console.error(`❌ Unknown scenario: ${scenarioName}`);
      this.showHelp();
      return;
    }

    console.log(`🚀 Connecting to Minecraft server at ${config.server.host}:${config.server.port}`);
    console.log(`📋 Running scenario: ${scenarioName}\n`);
    
    try {
      await this.scenarios[scenarioName]();
    } catch (error) {
      console.error('❌ Scenario failed:', error.message);
      this.botManager.disconnectAll();
    }
  }

  // Show help information
  showHelp() {
    console.log(`
🎮 Minecraft Analytics Bot Orchestrator

Usage: bun run index.js <scenario>

Available scenarios:
  demo       - 3 bots with normal behavior (10 minutes)
  stress     - Stress test with waves of bots
  chat       - 5 chatty bots focused on messaging (15 minutes)
  explorer   - 4 explorer bots that move around (20 minutes)
  mixed      - 6 bots with mixed behaviors (30 minutes)
  continuous - Continuous bot spawning (until stopped)

Environment variables:
  MINECRAFT_HOST - Server hostname (default: localhost)
  MINECRAFT_PORT - Server port (default: 25565)
  VERBOSE        - Enable verbose logging (default: false)

Examples:
  bun run index.js demo
  MINECRAFT_HOST=your-server.com bun run index.js continuous
  VERBOSE=true bun run index.js chat
`);
  }
}

// Main execution
async function main() {
  const orchestrator = new MinecraftBotOrchestrator();
  
  const scenario = process.argv[2];
  
  if (!scenario) {
    orchestrator.showHelp();
    return;
  }
  
  if (scenario === 'help' || scenario === '--help' || scenario === '-h') {
    orchestrator.showHelp();
    return;
  }
  
  await orchestrator.runScenario(scenario);
}

// Handle unhandled errors
process.on('unhandledRejection', (error) => {
  console.error('❌ Unhandled error:', error.message);
  process.exit(1);
});

// Run the main function
main().catch(console.error); 