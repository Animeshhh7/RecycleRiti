// backend/routes/educational_content_route.js
const express = require('express');
const router = express.Router();
const { EducationalContent, User, sequelize } = require('../models');
const { authenticateJWT } = require('../middleware/auth');
const path = require('path');
const fs = require('fs');

// GET /api/educational-content - Fetch all blog posts
router.get('/', async (req, res) => {
  try {
    // Test database connection
    console.log('Testing database connection in GET /api/educational-content...');
    await sequelize.authenticate();
    console.log('Database connection is active');

    // Fetch data using Sequelize
    const contents = await EducationalContent.findAll({
      include: [{ model: User, as: 'user', attributes: ['id', 'username'] }],
      order: [['createdAt', 'DESC']],
    });
    console.log('Sequelize query results:', contents);

    res.status(200).json({ success: true, contents });
  } catch (error) {
    console.error('Error fetching educational content:', error);
    console.error('Error details:', error.message, error.stack);
    res.status(500).json({ success: false, message: 'Failed to fetch educational content', error: error.message });
  }
});

// POST /api/educational-content - Create a new blog post with image
router.post('/', authenticateJWT, async (req, res) => {
  try {
    const { title, content, category, imageBase64 } = req.body;
    const userId = req.user.id; // From the authenticated token

    console.log('Creating blog post with userId:', userId);

    // Test database connection
    console.log('Testing database connection in POST /api/educational-content...');
    await sequelize.authenticate();
    console.log('Database connection is active');

    // Verify the user exists
    const user = await User.findByPk(userId);
    if (!user) {
      console.log('User not found for userId:', userId);
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    if (!title || !content || !category) {
      return res.status(400).json({ success: false, message: 'Title, content, and category are required' });
    }

    let imageUrl = null;
    if (imageBase64) {
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
      const filename = `blogImage-${Date.now()}-${Math.round(Math.random() * 1E9)}${extension}`;
      const filePath = path.join(__dirname, '../uploads/blog_images', filename);
      const filePathForStorage = `/uploads/blog_images/${filename}`;

      // Ensure the blog_images directory exists
      const blogImagesDir = path.join(__dirname, '../uploads/blog_images');
      if (!fs.existsSync(blogImagesDir)) {
        fs.mkdirSync(blogImagesDir, { recursive: true });
      }

      // Decode the base64 data and save it to a file
      const buffer = Buffer.from(base64Data, 'base64');
      fs.writeFileSync(filePath, buffer);
      console.log('Blog image saved to:', filePath);

      imageUrl = filePathForStorage;
    }

    const newContent = await EducationalContent.create({
      title: title.trim(),
      content: content.trim(),
      category: category.trim(),
      userId,
      imageUrl,
    });

    res.status(201).json({ success: true, content: newContent });
  } catch (error) {
    console.error('Error creating educational content:', error);
    console.error('Error details:', error.message, error.stack);
    res.status(500).json({ success: false, message: 'Failed to create educational content', error: error.message });
  }
});

// PUT /api/educational-content/:id - Update a blog post
router.put('/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, content, category, imageBase64 } = req.body;
    const userId = req.user.id;

    // Find the blog post
    const blog = await EducationalContent.findByPk(id);
    if (!blog) {
      return res.status(404).json({ success: false, message: 'Blog post not found' });
    }

    // Verify the user owns the blog post
    if (blog.userId !== userId) {
      return res.status(403).json({ success: false, message: 'Not authorized to edit this blog post' });
    }

    let imageUrl = blog.imageUrl; // Keep existing image by default
    if (imageBase64) {
      // Validate base64 string format
      const matches = imageBase64.match(/^data:image\/([a-zA-Z]+);base64,(.+)$/);
      if (!matches || matches.length !== 3) {
        return res.status(400).json({ success: false, message: 'Invalid image data format' });
      }

      const imageType = matches[1];
      const base64Data = matches[2];
      const extension = imageType === 'jpeg' ? '.jpg' : `.${imageType}`;

      if (!['jpeg', 'png'].includes(imageType)) {
        return res.status(400).json({ success: false, message: 'Only JPEG and PNG images are allowed' });
      }

      // Generate a unique filename
      const filename = `blogImage-${Date.now()}-${Math.round(Math.random() * 1E9)}${extension}`;
      const filePath = path.join(__dirname, '../uploads/blog_images', filename);
      const filePathForStorage = `/uploads/blog_images/${filename}`;

      // Ensure the blog_images directory exists
      const blogImagesDir = path.join(__dirname, '../uploads/blog_images');
      if (!fs.existsSync(blogImagesDir)) {
        fs.mkdirSync(blogImagesDir, { recursive: true });
      }

      // Decode the base64 data and save it to a file
      const buffer = Buffer.from(base64Data, 'base64');
      fs.writeFileSync(filePath, buffer);
      console.log('Blog image saved to:', filePath);

      // Delete the old image if it exists
      if (imageUrl) {
        const oldImagePath = path.join(__dirname, '..', imageUrl);
        if (fs.existsSync(oldImagePath)) {
          fs.unlinkSync(oldImagePath);
          console.log('Old blog image deleted:', oldImagePath);
        }
      }

      imageUrl = filePathForStorage;
    }

    // Update the blog post
    await blog.update({
      title: title?.trim() || blog.title,
      content: content?.trim() || blog.content,
      category: category?.trim() || blog.category,
      imageUrl,
    });

    res.status(200).json({ success: true, content: blog });
  } catch (error) {
    console.error('Error updating educational content:', error);
    console.error('Error details:', error.message, error.stack);
    res.status(500).json({ success: false, message: 'Failed to update educational content', error: error.message });
  }
});

// DELETE /api/educational-content/:id - Delete a blog post
router.delete('/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Find the blog post
    const blog = await EducationalContent.findByPk(id);
    if (!blog) {
      return res.status(404).json({ success: false, message: 'Blog post not found' });
    }

    // Verify the user owns the blog post
    if (blog.userId !== userId) {
      return res.status(403).json({ success: false, message: 'Not authorized to delete this blog post' });
    }

    // Delete the image if it exists
    if (blog.imageUrl) {
      const imagePath = path.join(__dirname, '..', blog.imageUrl);
      if (fs.existsSync(imagePath)) {
        fs.unlinkSync(imagePath);
        console.log('Blog image deleted:', imagePath);
      }
    }

    // Delete the blog post
    await blog.destroy();

    res.status(200).json({ success: true, message: 'Blog post deleted successfully' });
  } catch (error) {
    console.error('Error deleting educational content:', error);
    console.error('Error details:', error.message, error.stack);
    res.status(500).json({ success: false, message: 'Failed to delete educational content', error: error.message });
  }
});

module.exports = router;