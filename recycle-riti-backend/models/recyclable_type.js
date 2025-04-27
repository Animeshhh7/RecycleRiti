module.exports = (sequelize, DataTypes) => {
  const RecyclableType = sequelize.define('RecyclableType', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    name: { type: DataTypes.STRING, allowNull: false, unique: true },
    description: { type: DataTypes.TEXT, allowNull: true },
    createdAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updatedAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  }, {
    tableName: 'RecyclableTypes',
    timestamps: true,
  });

  RecyclableType.associate = (models) => {
    RecyclableType.hasMany(models.PickupRequest, { foreignKey: 'recyclableTypeId', as: 'pickupRequests' });
  };

  return RecyclableType;
};