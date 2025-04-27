const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { User, RefreshToken, sequelize } = require('../models');
const path = require('path');
const fs = require('fs');
const { Op } = require('sequelize');

const userController = {
  registerUser: async (req, res) => {
    try {
      const { username, email, password, role } = req.body;
      if (!username || !email || !password) {
        return res.status(400).json({ success: false, message: 'Fill all fields' });
      }

      const userExists = await User.findOne({ where: { email } });
      if (userExists) {
        return res.status(400).json({ success: false, message: 'Email taken' });
      }

      const hashed = await bcrypt.hash(password, 10);
      const user = await User.create({ username, email, password: hashed, role: role || 'user' });

      const accessToken = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: '15m' });
      const refreshToken = jwt.sign({ id: user.id }, process.env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      await RefreshToken.create({
        token: refreshToken,
        userId: user.id,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      });

      res.status(201).json({
        success: true,
        message: 'User made',
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          role: user.role,
          profileImage: user.profileImage,
          phone: user.phone,
          createdAt: user.createdAt,
          updatedAt: user.updatedAt,
        },
        accessToken,
        refreshToken,
      });
    } catch (error) {
      console.error('Register user error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error making user' });
    }
  },

  loginUser: async (req, res) => {
    try {
      const { email, password } = req.body;
      if (!email || !password) {
        return res.status(400).json({ success: false, message: 'Fill all fields' });
      }

      console.log(`Attempting to find user with email: ${email}`);
      const user = await User.findOne({ where: { email } });
      if (!user) {
        console.log(`User not found for email: ${email}`);
        return res.status(401).json({ success: false, message: 'Wrong email or password' });
      }

      console.log(`User found: ${user.id}, verifying ID...`);
      const userById = await User.findByPk(user.id);
      if (!userById) {
        console.log(`User not found by ID: ${user.id}`);
        return res.status(404).json({ success: false, message: 'User not found by ID' });
      }

      console.log(`Verifying password for user: ${user.id}`);
      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        console.log(`Password mismatch for user: ${user.id}`);
        return res.status(401).json({ success: false, message: 'Wrong email or password' });
      }

      console.log(`Generating tokens for user: ${user.id}`);
      const accessToken = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: '15m' });
      const refreshToken = jwt.sign({ id: user.id }, process.env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      console.log(`Creating refresh token for user: ${user.id}`);
      await RefreshToken.create({
        token: refreshToken,
        userId: user.id,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      });

      console.log(`Login successful for user: ${user.id}`);
      const userData = user.get({ plain: true });
      res.json({
        success: true,
        message: 'Login done',
        user: {
          id: userData.id,
          username: userData.username,
          email: userData.email,
          role: userData.role,
          profileImage: userData.profileImage,
          phone: userData.phone,
          createdAt: userData.createdAt,
          updatedAt: userData.updatedAt,
        },
        accessToken,
        refreshToken,
      });
    } catch (error) {
      console.error('Login user error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error logging in', error: error.message });
    }
  },

  refreshToken: async (req, res) => {
    try {
      const { refreshToken } = req.body;
      if (!refreshToken) {
        return res.status(400).json({ success: false, message: 'Need refresh token' });
      }

      const token = await RefreshToken.findOne({
        where: {
          token: refreshToken,
          expiresAt: { [Op.gt]: new Date() },
        },
      });

      if (!token) {
        return res.status(401).json({ success: false, message: 'Bad or expired refresh token' });
      }

      const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
      const user = await User.findByPk(decoded.id);

      if (!user) {
        await RefreshToken.destroy({ where: { token: refreshToken } });
        return res.status(404).json({ success: false, message: 'User not found' });
      }

      const accessToken = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: '15m' });
      res.json({ success: true, message: 'Token refreshed', accessToken });
    } catch (error) {
      console.error('Refresh token error:', error.message, error.stack);
      if (error.name === 'TokenExpiredError') {
        return res.status(401).json({ success: false, message: 'Refresh token expired' });
      }
      if (error.name === 'JsonWebTokenError') {
        return res.status(401).json({ success: false, message: 'Invalid refresh token' });
      }
      res.status(500).json({ success: false, message: 'Error refreshing token' });
    }
  },

  logoutUser: async (req, res) => {
    try {
      const { refreshToken } = req.body;
      if (!refreshToken) {
        return res.status(400).json({ success: false, message: 'Need refresh token' });
      }

      await RefreshToken.destroy({ where: { token: refreshToken } });
      res.json({ success: true, message: 'Logout done' });
    } catch (error) {
      console.error('Logout user error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error logging out' });
    }
  },

  getProfile: async (req, res) => {
    try {
      console.log(`Fetching profile for user ID: ${req.user.id}`);

      // Test database connection before querying
      console.log('Testing database connection in getProfile...');
      await sequelize.authenticate();
      console.log('Database connection is active in getProfile');

      // Fetch user without including associations to avoid potential issues
      const user = await User.findByPk(req.user.id, {
        attributes: ['id', 'username', 'email', 'role', 'profileImage', 'phone', 'createdAt', 'updatedAt'],
      });
      if (!user) {
        console.log(`User not found for ID: ${req.user.id}`);
        return res.status(404).json({ success: false, message: 'User not found' });
      }
      console.log(`Profile found for user ID: ${req.user.id}`);
      res.json({ success: true, message: 'Profile found', user });
    } catch (error) {
      console.error('Get profile error:', error.message, error.stack);
      if (error.name === 'SequelizeConnectionError') {
        return res.status(500).json({ success: false, message: 'Database connection error', error: error.message });
      }
      if (error.name === 'SequelizeDatabaseError') {
        return res.status(500).json({ success: false, message: 'Database query error', error: error.message });
      }
      res.status(500).json({ success: false, message: 'Error getting profile', error: error.message });
    }
  },

  updateProfileImage: async (req, res) => {
    try {
      console.log('Received update profile image request');
      console.log('Request body:', req.body);

      const user = await User.findByPk(req.user.id);
      if (!user) {
        console.log(`User not found for ID: ${req.user.id}`);
        return res.status(404).json({ success: false, message: 'User not found' });
      }

      const { imageBase64 } = req.body;
      if (!imageBase64) {
        console.log('No imageBase64 provided in request');
        return res.status(400).json({ success: false, message: 'No image data provided' });
      }

      // Validate base64 string format
      const matches = imageBase64.match(/^data:image\/([a-zA-Z]+);base64,(.+)$/);
      if (!matches || matches.length !== 3) {
        return res.status(400).json({ success: false, message: 'Invalid image data format' });
      }

      const imageType = matches[1]; // e.g., 'jpeg', 'png'
      const base64Data = matches[2]; // The base64-encoded data
      const extension = imageType === 'jpeg' ? '.jpg' : `.${imageType}`;

      if (!['jpeg', 'png'].includes(imageType)) {
        return res.status(400).json({ success: false, message: 'Only JPEG and PNG images are allowed' });
      }

      // Generate a unique filename
      const filename = `profileImage-${Date.now()}-${Math.round(Math.random() * 1E9)}${extension}`;
      const filePath = path.join(__dirname, '../uploads', filename);
      const filePathForStorage = `/uploads/${filename}`;

      // Decode the base64 data and save it to a file
      const buffer = Buffer.from(base64Data, 'base64');
      fs.writeFileSync(filePath, buffer);
      console.log('Image saved to:', filePath);

      // Remove the old profile image if it exists
      if (user.profileImage) {
        const oldPath = path.join(__dirname, '..', user.profileImage);
        console.log('Removing old profile image at:', oldPath);
        if (fs.existsSync(oldPath)) {
          fs.unlinkSync(oldPath);
          console.log('Old profile image removed');
        } else {
          console.log('Old profile image not found at:', oldPath);
        }
      }

      // Update the user's profile image path
      user.profileImage = filePathForStorage;
      await user.save();
      console.log('Profile image updated for user ID:', req.user.id);
      res.json({ success: true, message: 'Image updated', profileImage: user.profileImage });
    } catch (error) {
      console.error('Update profile image error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error updating image', error: error.message });
    }
  },

  updateProfile: async (req, res) => {
    try {
      const { username, email, phone } = req.body;
      console.log('Update profile request body:', req.body);
      const user = await User.findByPk(req.user.id);
      if (!user) {
        return res.status(404).json({ success: false, message: 'User not found' });
      }

      if (!username && !email && !phone) {
        return res.status(400).json({ success: false, message: 'Provide at least one field to update (username, email, or phone)' });
      }

      if (email && email !== user.email) {
        const userExists = await User.findOne({ where: { email } });
        if (userExists) {
          return res.status(400).json({ success: false, message: 'Email taken' });
        }
        user.email = email;
      }
      if (username) user.username = username;
      if (phone !== undefined) user.phone = phone; // Handle phone update (allow clearing with empty string)

      await user.save();
      console.log('Profile updated for user ID:', req.user.id, 'New phone:', user.phone);
      res.json({
        success: true,
        message: 'Profile updated',
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          role: user.role,
          profileImage: user.profileImage,
          phone: user.phone,
          createdAt: user.createdAt,
          updatedAt: user.updatedAt,
        },
      });
    } catch (error) {
      console.error('Update profile error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error updating profile' });
    }
  },

  getAllUsers: async (req, res) => {
    try {
      const users = await User.findAll({
        attributes: ['id', 'username', 'email', 'role', 'profileImage', 'phone', 'createdAt', 'updatedAt'],
      });
      res.json({ success: true, message: 'Users found', users });
    } catch (error) {
      console.error('Get all users error:', error.message, error.stack);
      res.status(500).json({ success: false, message: 'Error getting users' });
    }
  },
};

module.exports = userController;