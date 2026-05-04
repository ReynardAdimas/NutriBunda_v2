package food

import (
	"errors"
	"nutribunda-backend/internal/database"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

var (
	ErrFoodNotFound    = errors.New("food not found")
	ErrFoodNameExists  = errors.New("food with this name already exists")
	ErrInvalidCategory = errors.New("category must be 'mpasi', 'ibu', or 'custom'")
)

// Service handles food operations
type Service struct {
	db *gorm.DB
}

// NewService creates a new food service
func NewService(db *gorm.DB) *Service {
	return &Service{
		db: db,
	}
}

// SearchRequest represents food search request
type SearchRequest struct {
	Query    string `form:"search"`
	Category string `form:"category"` // 'mpasi', 'ibu', 'custom', or empty for all
	Limit    int    `form:"limit"`
}

// SearchResponse represents food search response
type SearchResponse struct {
	Foods []database.Food `json:"foods"`
	Total int64           `json:"total"`
}

// CreateFoodRequest represents request body for creating a custom food
type CreateFoodRequest struct {
	Name                  string   `json:"name" binding:"required"`
	Category              string   `json:"category" binding:"required"`
	CaloriesPer100g       float64  `json:"calories_per_100g" binding:"required,min=0"`
	ProteinPer100g        float64  `json:"protein_per_100g" binding:"required,min=0"`
	CarbsPer100g          float64  `json:"carbs_per_100g" binding:"required,min=0"`
	FatPer100g            float64  `json:"fat_per_100g" binding:"required,min=0"`
	EstimatedPricePer100g *float64 `json:"estimated_price_per_100g"`
}

// SearchFoods searches for foods based on query and filters
// Mencakup category 'custom' agar makanan input manual bisa dicari
func (s *Service) SearchFoods(req *SearchRequest) (*SearchResponse, error) {
	query := s.db.Model(&database.Food{})

	// Apply search filter
	if req.Query != "" {
		searchTerm := "%" + strings.ToLower(req.Query) + "%"
		query = query.Where("LOWER(name) LIKE ?", searchTerm)
	}

	// Apply category filter
	if req.Category != "" {
		query = query.Where("category = ?", req.Category)
	}

	// Count total results
	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, err
	}

	// Apply limit
	if req.Limit > 0 {
		query = query.Limit(req.Limit)
	} else {
		query = query.Limit(50) // Default limit
	}

	// Execute query
	var foods []database.Food
	if err := query.Order("name ASC").Find(&foods).Error; err != nil {
		return nil, err
	}

	return &SearchResponse{
		Foods: foods,
		Total: total,
	}, nil
}

// GetFoodByID retrieves a food by ID
func (s *Service) GetFoodByID(foodID uuid.UUID) (*database.Food, error) {
	var food database.Food
	if err := s.db.Where("id = ?", foodID).First(&food).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrFoodNotFound
		}
		return nil, err
	}
	return &food, nil
}

// CreateFood membuat entri makanan baru di database
// Digunakan untuk menyimpan makanan input manual agar bisa dicari di kemudian hari
func (s *Service) CreateFood(req *CreateFoodRequest) (*database.Food, error) {
	// Validasi category — hanya boleh 'mpasi', 'ibu', atau 'custom'
	validCategories := map[string]bool{"mpasi": true, "ibu": true, "custom": true}
	if !validCategories[req.Category] {
		return nil, ErrInvalidCategory
	}

	// Cek apakah nama makanan sudah ada di kategori yang sama
	var existing database.Food
	err := s.db.Where("LOWER(name) = ? AND category = ?",
		strings.ToLower(strings.TrimSpace(req.Name)),
		req.Category,
	).First(&existing).Error

	if err == nil {
		// Makanan sudah ada — kembalikan yang sudah ada daripada duplikat
		return &existing, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	// Buat food baru
	food := database.Food{
		ID:                    uuid.New(),
		Name:                  strings.TrimSpace(req.Name),
		Category:              req.Category,
		CaloriesPer100g:       req.CaloriesPer100g,
		ProteinPer100g:        req.ProteinPer100g,
		CarbsPer100g:          req.CarbsPer100g,
		FatPer100g:            req.FatPer100g,
		EstimatedPricePer100g: req.EstimatedPricePer100g,
		CreatedAt:             time.Now(),
	}

	if err := s.db.Create(&food).Error; err != nil {
		return nil, err
	}

	return &food, nil
}

// GetAllFoods retrieves all foods (for sync purposes)
func (s *Service) GetAllFoods() ([]database.Food, error) {
	var foods []database.Food
	if err := s.db.Order("name ASC").Find(&foods).Error; err != nil {
		return nil, err
	}
	return foods, nil
}

// SyncResponse represents sync response with timestamp support
type SyncResponse struct {
	Foods      []database.Food `json:"foods"`
	DeletedIDs []string        `json:"deleted_ids"`
}

// GetFoodsForSync retrieves foods updated after a given timestamp
func (s *Service) GetFoodsForSync(lastSync string) (*SyncResponse, error) {
	var foods []database.Food

	query := s.db.Model(&database.Food{})
	if lastSync != "" {
		query = query.Where("created_at > ?", lastSync)
	}

	if err := query.Order("created_at ASC").Find(&foods).Error; err != nil {
		return nil, err
	}

	return &SyncResponse{
		Foods:      foods,
		DeletedIDs: []string{},
	}, nil
}