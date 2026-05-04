package database

import (
	"fmt"
	"log"
	"nutribunda-backend/configs"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func InitDB(config *configs.Config) (*gorm.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		config.DBHost,
		config.DBPort,
		config.DBUser,
		config.DBPassword,
		config.DBName,
		config.DBSSLMode,
	)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})

	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	log.Println("Database connection established successfully")
	return db, nil
}

func RunMigrations(db *gorm.DB) error {
	// Run auto-migration for all models
	err := db.AutoMigrate(
		&User{},
		&Food{},
		&Recipe{},
		&DiaryEntry{},
		&FavoriteRecipe{},
		&QuizQuestion{},
		&Notification{},
		&DailySteps{},
	)
	
	if err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	// Add unique constraint for favorite_recipes
	db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_user_recipe ON favorite_recipes(user_id, recipe_id)")

	log.Println("Database migrations completed successfully")
	return nil
}
