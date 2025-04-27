const { RecyclableType } = require('../models');

const recyclableController = {
  getRecyclableTypes: async (req, res) => {
    try {
      const types = await RecyclableType.findAll({
        attributes: ['id', 'name', 'description'],
      });
      res.json({ success: true, message: 'Types found', types });
    } catch (error) {
      res.status(500).json({ success: false, message: 'Error getting types' });
    }
  },
};

module.exports = recyclableController;