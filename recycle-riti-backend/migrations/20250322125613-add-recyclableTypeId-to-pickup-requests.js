'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn('PickupRequests', 'recyclableTypeId', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: {
        model: 'RecyclableTypes',
        key: 'id',
      },
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL',
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeColumn('PickupRequests', 'recyclableTypeId');
  },
};