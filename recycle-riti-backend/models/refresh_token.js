module.exports = (sequelize, DataTypes) => {
  const RefreshToken = sequelize.define('RefreshToken', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    userId: { 
      type: DataTypes.INTEGER, 
      allowNull: false, 
      field: 'user_id' // Map userId to user_id in the database (snake_case convention)
    },
    token: { type: DataTypes.TEXT, allowNull: false },
    createdAt: { 
      type: DataTypes.DATE, 
      allowNull: false, 
      defaultValue: DataTypes.NOW,
      field: 'created_at' // Map createdAt to created_at in the database
    },
    expiresAt: { 
      type: DataTypes.DATE, 
      allowNull: false,
      field: 'expires_at' // Map expiresAt to expires_at in the database
    },
  }, {
    tableName: 'refresh_tokens', // Ensure this matches the actual table name in the database (lowercase)
    timestamps: true,
    updatedAt: false, // Disable updatedAt since refresh tokens don't need an update timestamp
  });

  RefreshToken.associate = (models) => {
    RefreshToken.belongsTo(models.User, { 
      foreignKey: 'userId', 
      as: 'user', 
      onDelete: 'CASCADE' // Delete refresh tokens if the associated user is deleted
    });
  };

  return RefreshToken;
};