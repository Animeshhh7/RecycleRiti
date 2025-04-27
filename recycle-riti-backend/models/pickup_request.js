module.exports = (sequelize, DataTypes) => {
  const PickupRequest = sequelize.define('PickupRequest', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    userId: { type: DataTypes.INTEGER, allowNull: false },
    recyclableTypeId: { type: DataTypes.INTEGER, allowNull: true },
    quantity: { type: DataTypes.FLOAT, allowNull: false, defaultValue: 0, validate: { min: 0 } },
    pickupDate: { type: DataTypes.DATE, allowNull: false },
    frequency: { type: DataTypes.ENUM('Daily', 'Weekly', 'Monthly', 'One-Time'), allowNull: true, defaultValue: 'One-Time' },
    location: { type: DataTypes.STRING, allowNull: true },
    status: { type: DataTypes.ENUM('pending', 'accepted', 'completed', 'cancelled'), allowNull: false, defaultValue: 'pending' },
    createdAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updatedAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  }, {
    tableName: 'PickupRequests',
    timestamps: true,
  });

  PickupRequest.associate = (models) => {
    PickupRequest.belongsTo(models.User, { foreignKey: 'userId', as: 'user' });
    PickupRequest.belongsTo(models.RecyclableType, { foreignKey: 'recyclableTypeId', as: 'recyclableType' });
    PickupRequest.hasOne(models.PickupAssignment, { foreignKey: 'pickupRequestId', as: 'assignments' }); // Changed alias to 'assignments'
  };

  return PickupRequest;
};