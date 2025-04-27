require('dotenv').config();
const express = require('express');
const cors = require('cors');
const sequelize = require('./db');
const path = require('path');
const fs = require('fs');
const multer = require('multer');

// Initialize Express app
const app = express();

// Multer setup for file uploads (kept for other routes)
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, 'uploads')),
  filename: (req, file, cb) =>
    cb(null, Date.now() + '-' + Math.round(Math.random() * 1E9) + path.extname(file.originalname)),
});
const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (['image/jpeg', 'image/png'].includes(file.mimetype)) cb(null, true);
    else cb(new Error('Only JPEG and PNG allowed'), false);
  },
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
});

// Log environment variables for debugging
console.log('Environment Variables:');
console.log('FRONTEND_URL:', process.env.FRONTEND_URL);
console.log('JWT_SECRET:', process.env.JWT_SECRET);
console.log('JWT_REFRESH_SECRET:', process.env.JWT_REFRESH_SECRET);
console.log('DB_HOST:', process.env.DB_HOST);
console.log('DB_PORT:', process.env.DB_PORT);
console.log('DB_NAME:', process.env.DB_NAME);
console.log('DB_USER:', process.env.DB_USER);
console.log('NODE_ENV:', process.env.NODE_ENV);

// CORS setup
const corsOptions = {
  origin: ['http://10.0.2.2:8080', 'http://192.168.1.6:5000'],
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};
app.use(cors(corsOptions));

// Conditionally apply express.json() middleware with increased limit
app.use((req, res, next) => {
  // Skip JSON parsing for /pickup/complete/:id (no body expected)
  if (req.method === 'PUT' && req.path.match(/^\/api\/pickup\/complete\/\d+$/)) {
    console.log(`Skipping JSON parsing for ${req.method} ${req.path}`);
    return next();
  }
  // Apply JSON parsing for other routes with a 5MB limit
  express.json({ limit: '5mb' })(req, res, (err) => {
    if (err) {
      console.error(`JSON parsing error for ${req.method} ${req.path}:`, err.message);
      return res.status(400).json({ success: false, message: 'Invalid JSON payload', error: err.message });
    }
    // Log the payload size for debugging
    if (req.body) {
      const payloadSize = Buffer.byteLength(JSON.stringify(req.body), 'utf8');
      console.log(`Request payload size for ${req.method} ${req.path}: ${payloadSize / 1024} KB`);
    }
    next();
  });
});

app.use(express.urlencoded({ extended: true }));

// Create uploads directory if it doesn't exist
const uploadsPath = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsPath)) {
  fs.mkdirSync(uploadsPath, { recursive: true });
  console.log('Uploads directory created:', uploadsPath);
}

// Create blog_images directory inside uploads
const blogImagesPath = path.join(__dirname, 'uploads/blog_images');
if (!fs.existsSync(blogImagesPath)) {
  fs.mkdirSync(blogImagesPath, { recursive: true });
  console.log('Blog images directory created:', blogImagesPath);
}

// Serve static files
app.use(
  '/uploads',
  express.static(uploadsPath, {
    setHeaders: (res, filePath) => {
      const ext = path.extname(filePath).toLowerCase();
      res.setHeader(
        'Content-Type',
        { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png' }[ext] || 'application/octet-stream'
      );
    },
  })
);

// Routes
const userRoutes = require('./routes/auth_route');
const pickupRoutes = require('./routes/pickup_route');
const recyclableTypeRoutes = require('./routes/recyclable_type_route');
const educationalContentRoutes = require('./routes/educational_content_route'); // Updated import

// Log route mounting for debugging
console.log('Mounting auth routes at /api/auth');
app.use('/api/auth', userRoutes);

console.log('Mounting pickup routes at /api/pickup');
app.use('/api/pickup', pickupRoutes);

console.log('Mounting recyclable type routes at /api/recyclable-types');
app.use('/api/recyclable-types', recyclableTypeRoutes);

console.log('Mounting educational content routes at /api/educational-content');
app.use('/api/educational-content', educationalContentRoutes);

// Health check
app.get('/health', (req, res) => res.status(200).json({ success: true, message: 'Server running' }));

// Catch-all route for debugging 404 errors
app.use((req, res, next) => {
  console.log(`Route not found: ${req.method} ${req.originalUrl}`);
  res.status(404).json({ message: `Cannot ${req.method} ${req.originalUrl}` });
});

// Global error handling middleware
app.use((err, req, res, next) => {
  // Check if a response has already been sent
  if (res.headersSent) {
    return next(err); // Delegate to default error handler if headers are already sent
  }

  console.error('Error occurred:', err.message);
  console.error('Stack trace:', err.stack);
  if (err instanceof multer.MulterError) {
    return res.status(400).json({ success: false, message: `Multer error: ${err.message}` });
  }
  if (err.message === 'Only JPEG and PNG allowed') {
    return res.status(400).json({ success: false, message: err.message });
  }
  if (err instanceof SyntaxError && err.message.includes('JSON')) {
    return res.status(400).json({ success: false, message: 'Invalid JSON in request body' });
  }
  res.status(err.status || 500).json({
    success: false,
    message: 'Server error',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined,
  });
});

// Function to connect to the database with retries
const connectToDatabase = async (retries = 5, delay = 3000) => {
  for (let i = 0; i < retries; i++) {
    try {
      console.log(`Connecting to database (Try ${i + 1}/${retries})...`);
      await sequelize.authenticate();
      console.log('Database connected successfully!');
      return true;
    } catch (err) {
      console.error(`Cannot connect to database: ${err.message}`);
      if (i < retries - 1) {
        console.log(`Retrying in ${delay / 1000} seconds...`);
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }
  return false;
};

// Start the server after database sync
const startServer = async () => {
  try {
    // Connect to the database
    const isConnected = await connectToDatabase();
    if (!isConnected) {
      console.error('Failed to connect to database after retries. Exiting...');
      process.exit(1);
    }

    // Sync the database
    console.log('Syncing database...');
    await sequelize.sync({ force: false });
    console.log('Database synced successfully!');

    // Start the server
    const PORT = process.env.PORT || 5000;
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server running on port ${PORT}`);
      console.log(`CORS enabled for: ${process.env.FRONTEND_URL}`);
    });
  } catch (err) {
    console.error('Error syncing database:', err.message);
    console.error('Stack trace:', err.stack);
    process.exit(1);
  }
};

// Handle uncaught exceptions and rejections
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err.message);
  console.error('Stack trace:', err.stack);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise);
  console.error('Reason:', reason);
  process.exit(1);
});

startServer();