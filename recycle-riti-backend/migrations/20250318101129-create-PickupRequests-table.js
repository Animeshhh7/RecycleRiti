'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('PickupRequests', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
      },
      userId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Users',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      status: {
        type: Sequelize.ENUM('pending', 'accepted', 'completed', 'cancelled'),
        allowNull: false,
        defaultValue: 'pending',
      },
      pickupDate: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      frequency: {
        type: Sequelize.ENUM('Daily', 'Weekly', 'Monthly'),
        allowNull: false,
      },
      location: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      recyclableTypeId: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: {
          model: 'RecyclableTypes',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      createdAt: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updatedAt: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    }, {
      tableName: 'PickupRequests',
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('PickupRequests');
  },
};