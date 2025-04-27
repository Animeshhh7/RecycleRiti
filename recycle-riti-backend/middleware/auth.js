const jwt = require('jsonwebtoken');
const { User, sequelize } = require('../models');

const authenticateJWT = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.log('No or invalid Authorization header:', req.headers.authorization);
    return res.status(401).json({ success: false, message: 'Not logged in' });
  }

  const token = authHeader.split(' ')[1];
  console.log('Verifying token for route:', req.originalUrl);
  console.log('Token:', token);

  try {
    // Verify the token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log('Token decoded:', decoded);

    // Test database connection before querying
    console.log('Testing database connection in authenticateJWT...');
    await sequelize.authenticate();
    console.log('Database connection is active in authenticateJWT');

    // Fetch the user
    const user = await User.findByPk(decoded.id);
    if (!user) {
      console.log('User not found for id:', decoded.id);
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    console.log('User found:', user.toJSON());

    // Set req.user
    req.user = { id: user.id, role: user.role };
    console.log('req.user set:', req.user);
    next();
  } catch (error) {
    console.error('JWT verification error for route:', req.originalUrl);
    console.error('Error:', error.message, error.stack);
    if (error.name === 'TokenExpiredError') {
      console.log('Token expired');
      return res.status(401).json({ success: false, message: 'Token expired' });
    }
    if (error.name === 'SequelizeConnectionError') {
      return res.status(500).json({ success: false, message: 'Database connection error', error: error.message });
    }
    return res.status(401).json({ success: false, message: 'Not logged in' });
  }
};

const restrictTo = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      console.log(`Access denied for role: ${req.user?.role}, required roles: ${roles}`);
      return res.status(403).json({ success: false, message: 'Not allowed' });
    }
    next();
  };
};

module.exports = { authenticateJWT, restrictTo };