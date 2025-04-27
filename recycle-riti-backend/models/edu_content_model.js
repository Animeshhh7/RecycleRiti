module.exports = (sequelize, DataTypes) => {
  const EducationalContent = sequelize.define('EducationalContent', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    title: { type: DataTypes.STRING, allowNull: false },
    content: { type: DataTypes.TEXT, allowNull: false },
    category: { type: DataTypes.STRING, allowNull: false },
    createdAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updatedAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  }, {
    tableName: 'EducationalContents',
    timestamps: true,
  });

  EducationalContent.associate = (models) => {};

  return EducationalContent;
};