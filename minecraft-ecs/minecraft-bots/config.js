// Configuration for Minecraft bots
export const config = {
  // Server connection details
  server: {
    host: process.env.MINECRAFT_HOST || 'localhost', // Replace with your server IP
    port: parseInt(process.env.MINECRAFT_PORT) || 25565,
    version: '1.21.4' // Match your server version
  },

  // Bot behavior settings
  bots: {
    // Number of concurrent bots for different scenarios
    maxConcurrentBots: 10,
    
    // Bot name patterns
    namePatterns: [
      'TestBot',
      'AnalyticsBot',
      'DataBot',
      'PlayerBot',
      'DemoBot',
      'StatsBot',
      'MetricsBot',
      'PipelineBot'
    ],
    
    // Chat message templates
    chatMessages: [
      "Hello everyone!",
      "This server is awesome!",
      "Anyone want to build together?",
      "I love mining diamonds!",
      "Check out my house!",
      "Who wants to go exploring?",
      "This is a great server!",
      "Building is so much fun!",
      "Anyone seen any good caves?",
      "Let's go on an adventure!",
      "I found some iron ore!",
      "This world is beautiful!",
      "Thanks for the great server!",
      "Anyone want to trade items?",
      "I'm working on a big project!",
      "The landscape here is amazing!",
      "Found a village nearby!",
      "Anyone need help with building?",
      "This is my favorite server!",
      "Great community here!"
    ],

    // Activity patterns
    activities: {
      // How often bots perform actions (in milliseconds)
      chatInterval: { min: 30000, max: 120000 }, // 30s to 2min
      moveInterval: { min: 5000, max: 15000 },   // 5s to 15s
      jumpInterval: { min: 10000, max: 30000 },  // 10s to 30s
      
      // Session duration
      sessionDuration: { min: 300000, max: 1800000 }, // 5min to 30min
      
      // Reconnection delay
      reconnectDelay: { min: 60000, max: 300000 }, // 1min to 5min
    },

    // Death scenarios for generating death statistics
    deathScenarios: [
      'fall', 'lava', 'drowning', 'mob', 'pvp', 'explosion'
    ]
  },

  // Logging configuration
  logging: {
    verbose: process.env.VERBOSE === 'true',
    logBotActions: true,
    logServerEvents: true
  }
};

// Helper function to get random value in range
export function randomInRange(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// Helper function to get random item from array
export function randomChoice(array) {
  return array[Math.floor(Math.random() * array.length)];
}

// Helper function to generate bot name
export function generateBotName(index) {
  const pattern = randomChoice(config.bots.namePatterns);
  return `${pattern}_${index.toString().padStart(3, '0')}`;
} 