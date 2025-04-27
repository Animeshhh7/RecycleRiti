module.exports = (sequelize, DataTypes) => {
  const Reward = sequelize.define('Reward', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    userId: { type: DataTypes.INTEGER, allowNull: false },
    points: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0, validate: { min: 0 } },
    description: { type: DataTypes.STRING, allowNull: true },
    createdAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updatedAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  }, {
    tableName: 'Rewards',
    timestamps: true,
  });

  Reward.associate = (models) => {
    Reward.belongsTo(models.User, { foreignKey: 'userId', as: 'user' });
  };

  return Reward;
};