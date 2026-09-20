#!/usr/bin/env bun

import mineflayer from 'mineflayer';
import { config, randomInRange, randomChoice, generateBotName } from './config.js';

// Specialized bot for generating death statistics
class DeathBot {
  constructor(botName) {
    this.botName = botName;
    this.bot = null;
    this.deathCount = 0;
    this.isActive = false;
  }

  async connect() {
    this.bot = mineflayer.createBot({
      host: config.server.host,
      port: config.server.port,
      username: this.botName,
      version: config.server.version,
      auth: 'offline'
    });

    this.setupEventHandlers();
    return new Promise((resolve) => {
      this.bot.once('spawn', () => {
        this.isActive = true;
        resolve();
      });
    });
  }

  setupEventHandlers() {
    this.bot.on('login', () => {
      console.log(`💀 ${this.botName} connected (Death Bot)`);
    });

    this.bot.on('spawn', () => {
      console.log(`✨ ${this.botName} spawned, preparing for death scenarios...`);
      
      // Start death scenarios after a short delay
      setTimeout(() => {
        this.startDeathScenarios();
      }, 3000);
    });

    this.bot.on('death', () => {
      this.deathCount++;
      console.log(`💀 ${this.botName} died! (Death #${this.deathCount})`);
      
      // Respawn and continue after a delay
      setTimeout(() => {
        if (this.isActive) {
          console.log(`🔄 ${this.botName} respawning for more death scenarios...`);
          this.startDeathScenarios();
        }
      }, randomInRange(5000, 10000));
    });

    this.bot.on('error', (err) => {
      console.error(`❌ ${this.botName} error:`, err.message);
    });

    this.bot.on('end', () => {
      console.log(`🔌 ${this.botName} disconnected (${this.deathCount} deaths total)`);
      this.isActive = false;
    });
  }

  startDeathScenarios() {
    if (!this.isActive || !this.bot.player) return;

    // Choose a random death scenario
    const scenario = randomChoice(config.bots.deathScenarios);
    
    console.log(`🎭 ${this.botName} attempting death scenario: ${scenario}`);
    
    switch (scenario) {
      case 'fall':
        this.attemptFallDeath();
        break;
      case 'lava':
        this.attemptLavaDeath();
        break;
      case 'drowning':
        this.attemptDrowningDeath();
        break;
      case 'mob':
        this.attemptMobDeath();
        break;
      case 'explosion':
        this.attemptExplosionDeath();
        break;
      default:
        this.attemptRandomDeath();
    }
  }

  attemptFallDeath() {
    // Try to find a high place and jump
    const currentPos = this.bot.entity.position;
    
    // Look for blocks above to build up
    this.bot.chat("Going to find a high place to fall from!");
    
    // Simulate building up and falling
    setTimeout(() => {
      if (this.isActive) {
        this.bot.chat("Here I go... YOLO!");
        // In a real scenario, the bot would build up and jump
        // For simulation, we'll just trigger the next scenario
        setTimeout(() => this.startDeathScenarios(), randomInRange(30000, 60000));
      }
    }, 5000);
  }

  attemptLavaDeath() {
    this.bot.chat("Looking for lava to jump into!");
    
    // Simulate searching for lava
    setTimeout(() => {
      if (this.isActive) {
        this.bot.chat("Found some lava! This is going to hurt...");
        // In a real scenario, the bot would find and jump into lava
        setTimeout(() => this.startDeathScenarios(), randomInRange(45000, 90000));
      }
    }, 8000);
  }

  attemptDrowningDeath() {
    this.bot.chat("Time for a swim... without coming up for air!");
    
    // Simulate drowning
    setTimeout(() => {
      if (this.isActive) {
        this.bot.chat("Glub glub glub...");
        setTimeout(() => this.startDeathScenarios(), randomInRange(60000, 120000));
      }
    }, 10000);
  }

  attemptMobDeath() {
    this.bot.chat("Going to find some hostile mobs!");
    
    // Simulate mob encounter
    setTimeout(() => {
      if (this.isActive) {
        this.bot.chat("Oh no, a creeper! Come here you green guy!");
        setTimeout(() => this.startDeathScenarios(), randomInRange(30000, 90000));
      }
    }, 15000);
  }

  attemptExplosionDeath() {
    this.bot.chat("Time to make some TNT!");
    
    // Simulate explosion
    setTimeout(() => {
      if (this.isActive) {
        this.bot.chat("Lighting the TNT... this should be interesting!");
        setTimeout(() => this.startDeathScenarios(), randomInRange(20000, 40000));
      }
    }, 12000);
  }

  attemptRandomDeath() {
    const randomActions = [
      "I'm going to try something dangerous!",
      "Let's see what happens if I do this...",
      "YOLO! Time for some risky business!",
      "I wonder what this button does...",
      "Hold my pickaxe, watch this!"
    ];
    
    this.bot.chat(randomChoice(randomActions));
    
    setTimeout(() => {
      if (this.isActive) {
        this.startDeathScenarios();
      }
    }, randomInRange(30000, 120000));
  }

  disconnect() {
    this.isActive = false;
    if (this.bot) {
      this.bot.quit();
    }
  }

  getStats() {
    return {
      name: this.botName,
      deaths: this.deathCount,
      active: this.isActive
    };
  }
}

// Death Bot Manager
class DeathBotManager {
  constructor() {
    this.bots = [];
  }

  async createDeathBots(count) {
    console.log(`💀 Creating ${count} death bots...`);
    
    for (let i = 0; i < count; i++) {
      const botName = `DeathBot_${i.toString().padStart(3, '0')}`;
      const deathBot = new DeathBot(botName);
      
      try {
        await deathBot.connect();
        this.bots.push(deathBot);
        console.log(`✅ ${botName} connected and ready for death scenarios`);
        
        // Stagger bot creation
        if (i < count - 1) {
          await new Promise(resolve => setTimeout(resolve, randomInRange(3000, 8000)));
        }
      } catch (error) {
        console.error(`❌ Failed to create ${botName}:`, error.message);
      }
    }
  }

  showStats() {
    console.log('\n💀 Death Bot Statistics:');
    console.log('========================');
    
    let totalDeaths = 0;
    let activeBots = 0;
    
    this.bots.forEach(bot => {
      const stats = bot.getStats();
      totalDeaths += stats.deaths;
      if (stats.active) activeBots++;
      
      const status = stats.active ? '🟢' : '🔴';
      console.log(`${status} ${stats.name}: ${stats.deaths} deaths`);
    });
    
    console.log(`\nTotal Deaths: ${totalDeaths}`);
    console.log(`Active Bots: ${activeBots}/${this.bots.length}`);
    console.log('');
  }

  disconnectAll() {
    console.log('🛑 Disconnecting all death bots...');
    this.bots.forEach(bot => bot.disconnect());
    this.bots = [];
  }
}

// Main execution
async function main() {
  const manager = new DeathBotManager();
  
  const botCount = parseInt(process.argv[2]) || 3;
  const duration = parseInt(process.argv[3]) || 600; // 10 minutes default
  
  console.log(`💀 Death Bot Scenario`);
  console.log(`Creating ${botCount} death bots for ${duration} seconds`);
  console.log(`Server: ${config.server.host}:${config.server.port}\n`);
  
  try {
    await manager.createDeathBots(botCount);
    
    // Show stats every 30 seconds
    const statsInterval = setInterval(() => {
      manager.showStats();
    }, 30000);
    
    // Handle graceful shutdown
    process.on('SIGINT', () => {
      console.log('\n🛑 Shutting down death bots...');
      clearInterval(statsInterval);
      manager.disconnectAll();
      process.exit(0);
    });
    
    // Auto-disconnect after duration
    setTimeout(() => {
      console.log(`⏰ ${duration} seconds elapsed, shutting down...`);
      clearInterval(statsInterval);
      manager.disconnectAll();
      process.exit(0);
    }, duration * 1000);
    
    console.log('💀 Death bots are running! Press Ctrl+C to stop.');
    
  } catch (error) {
    console.error('❌ Death bot scenario failed:', error.message);
    manager.disconnectAll();
    process.exit(1);
  }
}

main().catch(console.error); 