'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn('EducationalContents', 'category', {
      type: Sequelize.STRING,
      allowNull: false,
      defaultValue: 'General', // Add a default value since the column is NOT NULL
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeColumn('EducationalContents', 'category');
  },
};