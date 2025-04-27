require('dotenv').config();
const Sequelize = require('sequelize');

// Database configuration for development and production
const config = {
  development: {
    username: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    dialect: 'postgres',
  },
  production: {
    use_env_variable: 'DATABASE_URL',
    dialect: 'postgres',
    dialectOptions: {
      ssl: {
        require: true,
        rejectUnauthorized: false,
      },
    },
  },
};

// Check environment (default to development)
const env = process.env.NODE_ENV || 'development';
const dbConfig = config[env];

// Check if all database details are provided for development
if (env === 'development') {
  if (!dbConfig.username || !dbConfig.database || !dbConfig.host || !dbConfig.port) {
    console.error('Please set DB_USER, DB_NAME, DB_HOST, and DB_PORT in .env file.');
    process.exit(1);
  }
}

// Create Sequelize instance
let sequelize;
if (dbConfig.use_env_variable) {
  sequelize = new Sequelize(process.env[dbConfig.use_env_variable], {
    dialect: dbConfig.dialect,
    dialectOptions: dbConfig.dialectOptions,
    logging: process.env.DB_LOGGING === 'true' ? console.log : false,
  });
} else {
  sequelize = new Sequelize(dbConfig.database, dbConfig.username, dbConfig.password, {
    host: dbConfig.host,
    port: dbConfig.port,
    dialect: dbConfig.dialect,
    logging: process.env.DB_LOGGING === 'true' ? console.log : false,
  });
}

module.exports = sequelize;