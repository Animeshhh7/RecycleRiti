module.exports = (sequelize, DataTypes) => {
  const PickupAssignment = sequelize.define(
    'PickupAssignment',
    {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true,
      },
      pickupRequestId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: {
          model: 'PickupRequests', // References the PickupRequests table
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE', // If the pickup request is deleted, delete the assignment
      },
      agentId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: {
          model: 'Users', // References the Users table
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL', // If the agent is deleted, set agentId to NULL
      },
      assignedAt: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      createdAt: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      updatedAt: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    },
    {
      tableName: 'PickupAssignments',
      timestamps: true,
    }
  );

  PickupAssignment.associate = (models) => {
    PickupAssignment.belongsTo(models.PickupRequest, { foreignKey: 'pickupRequestId', as: 'pickupRequest' });
    PickupAssignment.belongsTo(models.User, { foreignKey: 'agentId', as: 'agent' });
  };

  return PickupAssignment;
};