module.exports = (sequelize, DataTypes) => {
  const EventParticipant = sequelize.define('EventParticipant', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    userId: { type: DataTypes.INTEGER, allowNull: false },
    eventId: { type: DataTypes.INTEGER, allowNull: false },
    createdAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updatedAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  }, {
    tableName: 'EventParticipants',
    timestamps: true,
  });

  EventParticipant.associate = (models) => {
    EventParticipant.belongsTo(models.User, { foreignKey: 'userId', as: 'user' });
    EventParticipant.belongsTo(models.Event, { foreignKey: 'eventId', as: 'event' });
  };

  return EventParticipant;
};