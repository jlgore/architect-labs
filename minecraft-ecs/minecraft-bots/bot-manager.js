import mineflayer from 'mineflayer';
import { pathfinder, Movements } from 'mineflayer-pathfinder';
import { config, randomInRange, randomChoice, generateBotName } from './config.js';

export class BotManager {
  constructor() {
    this.bots = new Map();
    this.botCounter = 0;
    this.isRunning = false;
  }

  // Create a single bot with specified behavior
  async createBot(botName, behavior = 'normal') {
    const bot = mineflayer.createBot({
      host: config.server.host,
      port: config.server.port,
      username: botName,
      version: config.server.version,
      auth: 'offline' // For offline mode servers
    });

    // Load pathfinder plugin
    bot.loadPlugin(pathfinder);

    // Set up bot event handlers
    this.setupBotEvents(bot, behavior);

    // Store bot reference
    this.bots.set(botName, {
      bot,
      behavior,
      startTime: Date.now(),
      stats: {
        messagesSpoken: 0,
        deaths: 0,
        timesMoved: 0,
        achievements: 0
      }
    });

    return bot;
  }

  // Set up event handlers for a bot
  setupBotEvents(bot, behavior) {
    bot.on('login', () => {
      console.log(`🤖 ${bot.username} logged in to ${config.server.host}:${config.server.port}`);
      
      // Start bot activities after a short delay
      setTimeout(() => {
        this.startBotActivities(bot, behavior);
      }, 2000);
    });

    bot.on('spawn', () => {
      console.log(`✨ ${bot.username} spawned in the world`);
      
      // Set up pathfinder movements
      if (bot.pathfinder) {
        const mcData = require('minecraft-data')(bot.version);
        const defaultMove = new Movements(bot, mcData);
        bot.pathfinder.setMovements(defaultMove);
      }
    });

    bot.on('chat', (username, message) => {
      if (config.logging.logServerEvents) {
        console.log(`💬 ${username}: ${message}`);
      }
      
      // Respond to certain messages
      if (message.includes(bot.username) && username !== bot.username) {
        setTimeout(() => {
          const responses = [
            `Hello ${username}!`,
            `Hi there ${username}!`,
            `Hey ${username}, how are you?`,
            `Nice to meet you ${username}!`
          ];
          bot.chat(randomChoice(responses));
        }, randomInRange(1000, 3000));
      }
    });

    bot.on('death', () => {
      console.log(`💀 ${bot.username} died`);
      const botData = this.bots.get(bot.username);
      if (botData) {
        botData.stats.deaths++;
      }
      
      // Respawn after a delay
      setTimeout(() => {
        if (bot.game && bot.game.dimension) {
          console.log(`🔄 ${bot.username} respawning...`);
        }
      }, 2000);
    });

    bot.on('error', (err) => {
      console.error(`❌ ${bot.username} error:`, err.message);
    });

    bot.on('kicked', (reason) => {
      console.log(`👢 ${bot.username} was kicked: ${reason}`);
      this.removeBot(bot.username);
    });

    bot.on('end', () => {
      console.log(`🔌 ${bot.username} disconnected`);
      this.removeBot(bot.username);
    });
  }

  // Start activities for a bot based on its behavior
  startBotActivities(bot, behavior) {
    const activities = [];

    // Chat activity
    if (behavior === 'chatty' || behavior === 'normal') {
      const chatActivity = setInterval(() => {
        if (bot.player && bot.player.entity) {
          const message = randomChoice(config.bots.chatMessages);
          bot.chat(message);
          
          const botData = this.bots.get(bot.username);
          if (botData) {
            botData.stats.messagesSpoken++;
          }
          
          if (config.logging.logBotActions) {
            console.log(`💬 ${bot.username} said: ${message}`);
          }
        }
      }, randomInRange(
        config.bots.activities.chatInterval.min,
        config.bots.activities.chatInterval.max
      ));
      activities.push(chatActivity);
    }

    // Movement activity
    if (behavior === 'explorer' || behavior === 'normal') {
      const moveActivity = setInterval(() => {
        if (bot.player && bot.player.entity && bot.pathfinder) {
          // Move to a random nearby location
          const currentPos = bot.entity.position;
          const randomX = currentPos.x + randomInRange(-20, 20);
          const randomZ = currentPos.z + randomInRange(-20, 20);
          const randomY = currentPos.y;

          try {
            bot.pathfinder.setGoal(null); // Clear current goal
            bot.pathfinder.setGoal(new pathfinder.goals.GoalNear(randomX, randomY, randomZ, 1));
            
            const botData = this.bots.get(bot.username);
            if (botData) {
              botData.stats.timesMoved++;
            }
            
            if (config.logging.logBotActions) {
              console.log(`🚶 ${bot.username} moving to ${randomX.toFixed(1)}, ${randomY.toFixed(1)}, ${randomZ.toFixed(1)}`);
            }
          } catch (err) {
            // Ignore pathfinding errors
          }
        }
      }, randomInRange(
        config.bots.activities.moveInterval.min,
        config.bots.activities.moveInterval.max
      ));
      activities.push(moveActivity);
    }

    // Jumping activity
    const jumpActivity = setInterval(() => {
      if (bot.player && bot.player.entity) {
        bot.setControlState('jump', true);
        setTimeout(() => {
          bot.setControlState('jump', false);
        }, 100);
        
        if (config.logging.logBotActions) {
          console.log(`🦘 ${bot.username} jumped`);
        }
      }
    }, randomInRange(
      config.bots.activities.jumpInterval.min,
      config.bots.activities.jumpInterval.max
    ));
    activities.push(jumpActivity);

    // Store activities for cleanup
    const botData = this.bots.get(bot.username);
    if (botData) {
      botData.activities = activities;
    }

    // Schedule bot disconnection
    const sessionDuration = randomInRange(
      config.bots.activities.sessionDuration.min,
      config.bots.activities.sessionDuration.max
    );

    setTimeout(() => {
      this.disconnectBot(bot.username);
    }, sessionDuration);
  }

  // Disconnect a specific bot
  disconnectBot(botName) {
    const botData = this.bots.get(botName);
    if (botData) {
      // Clear activities
      if (botData.activities) {
        botData.activities.forEach(activity => clearInterval(activity));
      }
      
      // Disconnect bot
      if (botData.bot && botData.bot.player) {
        console.log(`👋 ${botName} leaving the server`);
        botData.bot.quit();
      }
      
      this.removeBot(botName);
    }
  }

  // Remove bot from tracking
  removeBot(botName) {
    this.bots.delete(botName);
  }

  // Create multiple bots with different behaviors
  async createMultipleBots(count, behaviors = ['normal']) {
    const promises = [];
    
    for (let i = 0; i < count; i++) {
      const botName = generateBotName(this.botCounter++);
      const behavior = randomChoice(behaviors);
      
      // Stagger bot creation to avoid overwhelming the server
      const delay = i * randomInRange(2000, 5000);
      
      const promise = new Promise((resolve) => {
        setTimeout(async () => {
          try {
            const bot = await this.createBot(botName, behavior);
            resolve(bot);
          } catch (err) {
            console.error(`Failed to create bot ${botName}:`, err.message);
            resolve(null);
          }
        }, delay);
      });
      
      promises.push(promise);
    }
    
    return Promise.all(promises);
  }

  // Get statistics for all bots
  getStats() {
    const stats = {
      totalBots: this.bots.size,
      activeBots: 0,
      totalMessages: 0,
      totalDeaths: 0,
      totalMoves: 0,
      bots: []
    };

    this.bots.forEach((botData, botName) => {
      if (botData.bot && botData.bot.player) {
        stats.activeBots++;
      }
      
      stats.totalMessages += botData.stats.messagesSpoken;
      stats.totalDeaths += botData.stats.deaths;
      stats.totalMoves += botData.stats.timesMoved;
      
      stats.bots.push({
        name: botName,
        behavior: botData.behavior,
        uptime: Date.now() - botData.startTime,
        stats: botData.stats,
        connected: botData.bot && botData.bot.player ? true : false
      });
    });

    return stats;
  }

  // Disconnect all bots
  disconnectAll() {
    console.log(`🛑 Disconnecting all ${this.bots.size} bots...`);
    
    this.bots.forEach((botData, botName) => {
      this.disconnectBot(botName);
    });
    
    this.isRunning = false;
  }

  // Start continuous bot spawning
  startContinuousSpawning(maxBots = 5, behaviors = ['normal']) {
    this.isRunning = true;
    
    const spawnInterval = setInterval(() => {
      if (!this.isRunning) {
        clearInterval(spawnInterval);
        return;
      }
      
      // Maintain a certain number of active bots
      const activeBots = Array.from(this.bots.values()).filter(
        botData => botData.bot && botData.bot.player
      ).length;
      
      if (activeBots < maxBots) {
        const botsToSpawn = Math.min(maxBots - activeBots, 2); // Spawn max 2 at a time
        this.createMultipleBots(botsToSpawn, behaviors);
      }
    }, 30000); // Check every 30 seconds
    
    return spawnInterval;
  }
} 