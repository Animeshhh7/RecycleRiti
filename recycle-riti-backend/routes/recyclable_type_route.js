const express = require('express');
const router = express.Router();
const { getRecyclableTypes } = require('../controllers/recyclable_controller');

router.get('/', getRecyclableTypes);

module.exports = router;