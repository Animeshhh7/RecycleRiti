module.exports = (sequelize, DataTypes) => {
  const User = sequelize.define('User', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    username: { type: DataTypes.STRING, allowNull: false, unique: true },
    email: { type: DataTypes.STRING, allowNull: false, unique: true, validate: { isEmail: true } },
    password: { type: DataTypes.STRING, allowNull: false },
    role: { type: DataTypes.ENUM('user', 'agent', 'admin'), allowNull: false, defaultValue: 'user' },
    profileImage: { type: DataTypes.STRING, allowNull: true },
    phone: { type: DataTypes.STRING, allowNull: true },
    createdAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updatedAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  }, {
    tableName: 'Users', 
    timestamps: true,
  });

  User.associate = (models) => {
    User.hasMany(models.PickupRequest, { foreignKey: 'userId', as: 'pickupRequests' });
    User.hasMany(models.EducationalContent, { foreignKey: 'userId', as: 'educationalContents' });
    User.hasMany(models.EventParticipant, { foreignKey: 'userId', as: 'eventParticipants' });
    User.hasMany(models.Reward, { foreignKey: 'userId', as: 'rewards' });
    User.hasMany(models.RefreshToken, { foreignKey: 'userId', as: 'refreshTokens', onDelete: 'CASCADE' });

  };

  return User;
};