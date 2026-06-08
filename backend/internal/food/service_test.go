package food

import (
	"nutribunda-backend/internal/database"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func setupTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	require.NoError(t, err)

	// Run migrations
	err = db.AutoMigrate(&database.Food{})
	require.NoError(t, err)

	return db
}

func cleanupTestDB(t *testing.T, db *gorm.DB) {
	db.Exec("DELETE FROM foods")
}

func seedTestFoods(t *testing.T, db *gorm.DB) {
	foods := []database.Food{
		{Name: "Bubur Beras", Category: "mpasi", CaloriesPer100g: 130, ProteinPer100g: 2.7, CarbsPer100g: 28.2, FatPer100g: 0.3},
		{Name: "Pisang", Category: "mpasi", CaloriesPer100g: 89, ProteinPer100g: 1.1, CarbsPer100g: 22.8, FatPer100g: 0.3},
		{Name: "Alpukat", Category: "mpasi", CaloriesPer100g: 160, ProteinPer100g: 2.0, CarbsPer100g: 8.5, FatPer100g: 14.7},
		{Name: "Nasi Putih", Category: "ibu", CaloriesPer100g: 130, ProteinPer100g: 2.7, CarbsPer100g: 28.2, FatPer100g: 0.3},
		{Name: "Dada Ayam", Category: "ibu", CaloriesPer100g: 165, ProteinPer100g: 31.0, CarbsPer100g: 0.0, FatPer100g: 3.6},
	}

	for _, food := range foods {
		require.NoError(t, db.Create(&food).Error)
	}
}

func TestSearchFoods(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)
	seedTestFoods(t, db)
	service := NewService(db)

	t.Run("search all foods", func(t *testing.T) {
		req := &SearchRequest{
			Query:    "",
			Category: "",
			Limit:    10,
		}

		result, err := service.SearchFoods(req)
		assert.NoError(t, err)
		assert.Equal(t, int64(5), result.Total)
		assert.Len(t, result.Foods, 5)
	})

	t.Run("search by name", func(t *testing.T) {
		req := &SearchRequest{
			Query:    "bubur",
			Category: "",
			Limit:    10,
		}

		result, err := service.SearchFoods(req)
		assert.NoError(t, err)
		assert.Equal(t, int64(1), result.Total)
		assert.Len(t, result.Foods, 1)
		assert.Equal(t, "Bubur Beras", result.Foods[0].Name)
	})

	t.Run("search by category mpasi", func(t *testing.T) {
		req := &SearchRequest{
			Query:    "",
			Category: "mpasi",
			Limit:    10,
		}

		result, err := service.SearchFoods(req)
		assert.NoError(t, err)
		assert.Equal(t, int64(3), result.Total)
		assert.Len(t, result.Foods, 3)
		for _, food := range result.Foods {
			assert.Equal(t, "mpasi", food.Category)
		}
	})

	t.Run("search by category ibu", func(t *testing.T) {
		req := &SearchRequest{
			Query:    "",
			Category: "ibu",
			Limit:    10,
		}

		result, err := service.SearchFoods(req)
		assert.NoError(t, err)
		assert.Equal(t, int64(2), result.Total)
		assert.Len(t, result.Foods, 2)
		for _, food := range result.Foods {
			assert.Equal(t, "ibu", food.Category)
		}
	})

	t.Run("search with name and category", func(t *testing.T) {
		req := &SearchRequest{
			Query:    "ayam",
			Category: "ibu",
			Limit:    10,
		}

		result, err := service.SearchFoods(req)
		assert.NoError(t, err)
		assert.Equal(t, int64(1), result.Total)
		assert.Len(t, result.Foods, 1)
		assert.Equal(t, "Dada Ayam", result.Foods[0].Name)
	})

	t.Run("search with limit", func(t *testing.T) {
		req := &SearchRequest{
			Query:    "",
			Category: "",
			Limit:    2,
		}

		result, err := service.SearchFoods(req)
		assert.NoError(t, err)
		assert.Equal(t, int64(5), result.Total)
		assert.Len(t, result.Foods, 2)
	})

	t.Run("search case insensitive", func(t *testing.T) {
		req := &SearchRequest{
			Query:    "PISANG",
			Category: "",
			Limit:    10,
		}

		result, err := service.SearchFoods(req)
		assert.NoError(t, err)
		assert.Equal(t, int64(1), result.Total)
		assert.Len(t, result.Foods, 1)
		assert.Equal(t, "Pisang", result.Foods[0].Name)
	})
}

func TestGetFoodByID(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)
	seedTestFoods(t, db)
	service := NewService(db)

	t.Run("get existing food", func(t *testing.T) {
		// Get the first food from database
		var food database.Food
		db.First(&food)

		result, err := service.GetFoodByID(food.ID)
		assert.NoError(t, err)
		assert.NotNil(t, result)
		assert.Equal(t, food.ID, result.ID)
		assert.Equal(t, food.Name, result.Name)
	})

	t.Run("get non-existing food", func(t *testing.T) {
		nonExistingID := uuid.New()

		result, err := service.GetFoodByID(nonExistingID)
		assert.Error(t, err)
		assert.Equal(t, ErrFoodNotFound, err)
		assert.Nil(t, result)
	})
}

func TestGetAllFoods(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)
	seedTestFoods(t, db)
	service := NewService(db)

	t.Run("get all foods", func(t *testing.T) {
		foods, err := service.GetAllFoods()
		assert.NoError(t, err)
		assert.Len(t, foods, 5)
	})
}

func TestGetFoodsForSync(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)
	seedTestFoods(t, db)
	service := NewService(db)

	t.Run("sync without timestamp", func(t *testing.T) {
		result, err := service.GetFoodsForSync("")
		assert.NoError(t, err)
		assert.Len(t, result.Foods, 5)
		assert.Len(t, result.DeletedIDs, 0)
	})

	t.Run("sync with old timestamp", func(t *testing.T) {
		result, err := service.GetFoodsForSync("2020-01-01T00:00:00Z")
		assert.NoError(t, err)
		assert.Len(t, result.Foods, 5)
	})

	t.Run("sync with future timestamp", func(t *testing.T) {
		result, err := service.GetFoodsForSync("2030-01-01T00:00:00Z")
		assert.NoError(t, err)
		assert.Len(t, result.Foods, 0)
	})
}
