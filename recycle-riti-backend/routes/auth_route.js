const express = require('express');
const router = express.Router();
const { authenticateJWT, restrictTo } = require('../middleware/auth');
const userController = require('../controllers/user_controller');

// Route for user registration
router.post('/signup', userController.registerUser);

// Route for user login
router.post('/login', userController.loginUser);

// Route to get user profile (requires authentication)
router.get('/profile', authenticateJWT, userController.getProfile);

// Route to update user profile image (requires authentication)
router.post('/update-profile-image', authenticateJWT, userController.updateProfileImage);

// Route to update user profile details (requires authentication)
router.put('/update-profile', authenticateJWT, userController.updateProfile);

// Route to refresh access token using refresh token
router.post('/refresh-token', userController.refreshToken);

// Route for user logout
router.post('/logout', userController.logoutUser);

// Route to get all users (requires authentication and admin role)
router.get('/users', authenticateJWT, restrictTo('admin'), userController.getAllUsers);

module.exports = router;