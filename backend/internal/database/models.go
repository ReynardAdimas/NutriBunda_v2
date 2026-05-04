package database

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// User represents a user in the system
type User struct {
	ID              uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Email           string    `gorm:"type:varchar(255);unique;not null" json:"email"`
	PasswordHash    string    `gorm:"type:varchar(255);not null" json:"-"`
	FullName        string    `gorm:"type:varchar(255);not null" json:"full_name"`
	Weight          *float64  `gorm:"type:decimal(5,2)" json:"weight"`
	Height          *float64  `gorm:"type:decimal(5,2)" json:"height"`
	Age             *int      `gorm:"type:integer" json:"age"`
	IsBreastfeeding bool      `gorm:"default:false" json:"is_breastfeeding"`
	ActivityLevel   string    `gorm:"type:varchar(20);default:'sedentary'" json:"activity_level"`
	ProfileImageURL *string   `gorm:"type:text" json:"profile_image_url"`
	Timezone        string    `gorm:"type:varchar(10);default:'WIB'" json:"timezone"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// Food represents a food item in the database
type Food struct {
	ID              uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name            string    `gorm:"type:varchar(255);not null" json:"name"`
	Category        string    `gorm:"type:varchar(50);not null" json:"category"` // 'mpasi' or 'ibu'
	CaloriesPer100g float64   `gorm:"type:decimal(6,2);not null" json:"calories_per_100g"`
	ProteinPer100g  float64   `gorm:"type:decimal(5,2);not null" json:"protein_per_100g"`
	CarbsPer100g    float64   `gorm:"type:decimal(5,2);not null" json:"carbs_per_100g"`
	FatPer100g      float64   `gorm:"type:decimal(5,2);not null" json:"fat_per_100g"`
	EstimatedPricePer100g *float64 `gorm:"type:decimal(10,2)" json:"estimated_price_per_100g"`
	CreatedAt       time.Time `json:"created_at"`
}

// Recipe represents a recipe
type Recipe struct {
	ID            uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name          string    `gorm:"type:varchar(255);not null" json:"name"`
	Ingredients   string    `gorm:"type:text;not null" json:"ingredients"` // JSON array
	Instructions  string    `gorm:"type:text;not null" json:"instructions"`
	NutritionInfo string    `gorm:"type:jsonb" json:"nutrition_info"` // JSON object
	Category      string    `gorm:"type:varchar(50);default:'mpasi'" json:"category"`
	CreatedAt     time.Time `json:"created_at"`
}

// DiaryEntry represents a food diary entry
type DiaryEntry struct {
	ID             uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	UserID         uuid.UUID  `gorm:"type:uuid;not null" json:"user_id"`
	User           User       `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE" json:"-"`
	ProfileType    string     `gorm:"type:varchar(10);not null" json:"profile_type"` // 'baby' or 'mother'
	FoodID         *uuid.UUID `gorm:"type:uuid" json:"food_id"`
	Food           *Food      `gorm:"foreignKey:FoodID" json:"food,omitempty"`
	CustomFoodName *string    `gorm:"type:varchar(255)" json:"custom_food_name"`
	ServingSize    float64    `gorm:"type:decimal(6,2);not null" json:"serving_size"` // grams
	MealTime       string     `gorm:"type:varchar(20);not null" json:"meal_time"`     // 'breakfast', 'lunch', 'dinner', 'snack'
	Calories       float64    `gorm:"type:decimal(6,2);not null" json:"calories"`
	Protein        float64    `gorm:"type:decimal(5,2);not null" json:"protein"`
	Carbs          float64    `gorm:"type:decimal(5,2);not null" json:"carbs"`
	Fat            float64    `gorm:"type:decimal(5,2);not null" json:"fat"`
	EntryDate      time.Time  `gorm:"type:date;not null" json:"entry_date"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
	DeletedAt      *time.Time `gorm:"index" json:"deleted_at,omitempty"` // Soft delete for sync
}

// FavoriteRecipe represents a user's favorite recipe
type FavoriteRecipe struct {
	ID        uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	UserID    uuid.UUID  `gorm:"type:uuid;not null" json:"user_id"`
	User      User       `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE" json:"-"`
	RecipeID  uuid.UUID  `gorm:"type:uuid;not null" json:"recipe_id"`
	Recipe    Recipe     `gorm:"foreignKey:RecipeID;constraint:OnDelete:CASCADE" json:"recipe,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	DeletedAt *time.Time `gorm:"index" json:"deleted_at,omitempty"` // Soft delete for sync
}

// QuizQuestion represents a quiz question
type QuizQuestion struct {
	ID            uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Question      string    `gorm:"type:text;not null" json:"question"`
	OptionA       string    `gorm:"type:varchar(255);not null" json:"option_a"`
	OptionB       string    `gorm:"type:varchar(255);not null" json:"option_b"`
	OptionC       string    `gorm:"type:varchar(255);not null" json:"option_c"`
	OptionD       string    `gorm:"type:varchar(255);not null" json:"option_d"`
	CorrectAnswer string    `gorm:"type:char(1);not null" json:"correct_answer"` // 'A', 'B', 'C', 'D'
	Explanation   *string   `gorm:"type:text" json:"explanation"`
	CreatedAt     time.Time `json:"created_at"`
}

// Notification represents a notification setting
type Notification struct {
	ID            uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	UserID        uuid.UUID `gorm:"type:uuid;not null" json:"user_id"`
	User          User      `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE" json:"-"`
	Type          string    `gorm:"type:varchar(50);not null" json:"type"` // 'mpasi_meal', 'vitamin'
	Title         string    `gorm:"type:varchar(255);not null" json:"title"`
	Message       string    `gorm:"type:text;not null" json:"message"`
	ScheduledTime string    `gorm:"type:time;not null" json:"scheduled_time"`
	IsActive      bool      `gorm:"default:true" json:"is_active"`
	CreatedAt     time.Time `json:"created_at"`
}

// DailySteps represents pedometer data per day per user
type DailySteps struct {
    ID             uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
    UserID         uuid.UUID `gorm:"type:uuid;not null" json:"user_id"`
    User           User      `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE" json:"-"`
    Date           time.Time `gorm:"type:date;not null" json:"date"`
    Steps          int       `gorm:"not null;default:0" json:"steps"`
    CaloriesBurned float64   `gorm:"type:decimal(7,2);not null;default:0" json:"calories_burned"`
    CreatedAt      time.Time `json:"created_at"`
    UpdatedAt      time.Time `json:"updated_at"`
}

// BeforeCreate hook for DailySteps
func (d *DailySteps) BeforeCreate(tx *gorm.DB) error {
    if d.ID == uuid.Nil {
        d.ID = uuid.New()
    }
    return nil
}

// BeforeCreate hook for User to generate UUID
func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	return nil
}

// BeforeCreate hook for Food to generate UUID
func (f *Food) BeforeCreate(tx *gorm.DB) error {
	if f.ID == uuid.Nil {
		f.ID = uuid.New()
	}
	return nil
}

// BeforeCreate hook for Recipe to generate UUID
func (r *Recipe) BeforeCreate(tx *gorm.DB) error {
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	return nil
}

// BeforeCreate hook for DiaryEntry to generate UUID
func (d *DiaryEntry) BeforeCreate(tx *gorm.DB) error {
	if d.ID == uuid.Nil {
		d.ID = uuid.New()
	}
	return nil
}

// BeforeCreate hook for FavoriteRecipe to generate UUID
func (f *FavoriteRecipe) BeforeCreate(tx *gorm.DB) error {
	if f.ID == uuid.Nil {
		f.ID = uuid.New()
	}
	return nil
}

// BeforeCreate hook for QuizQuestion to generate UUID
func (q *QuizQuestion) BeforeCreate(tx *gorm.DB) error {
	if q.ID == uuid.Nil {
		q.ID = uuid.New()
	}
	return nil
}

// BeforeCreate hook for Notification to generate UUID
func (n *Notification) BeforeCreate(tx *gorm.DB) error {
	if n.ID == uuid.Nil {
		n.ID = uuid.New()
	}
	return nil
}
