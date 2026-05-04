package steps

import (
    "errors"
    "nutribunda-backend/internal/database"
    "time"

    "github.com/google/uuid"
    "gorm.io/gorm"
    "gorm.io/gorm/clause"
)

var ErrInvalidDate = errors.New("invalid date format")

type Service struct {
    db *gorm.DB
}

func NewService(db *gorm.DB) *Service {
    return &Service{db: db}
}

type UpsertStepsRequest struct {
    Date           string  `json:"date" binding:"required"` // "YYYY-MM-DD"
    Steps          int     `json:"steps" binding:"min=0"`
    CaloriesBurned float64 `json:"calories_burned" binding:"min=0"`
}

// UpsertDailySteps menyimpan atau mengupdate data steps untuk suatu hari
func (s *Service) UpsertDailySteps(userID uuid.UUID, req *UpsertStepsRequest) (*database.DailySteps, error) {
    date, err := time.Parse("2006-01-02", req.Date)
    if err != nil {
        return nil, ErrInvalidDate
    }

    record := database.DailySteps{
        UserID:         userID,
        Date:           date,
        Steps:          req.Steps,
        CaloriesBurned: req.CaloriesBurned,
    }

    // UPSERT: insert, jika konflik pada (user_id, date) maka update
    result := s.db.Clauses(clause.OnConflict{
        Columns:   []clause.Column{{Name: "user_id"}, {Name: "date"}},
        DoUpdates: clause.AssignmentColumns([]string{"steps", "calories_burned", "updated_at"}),
    }).Create(&record)

    if result.Error != nil {
        return nil, result.Error
    }

    return &record, nil
}

// GetDailySteps mengambil data steps untuk tanggal tertentu
func (s *Service) GetDailySteps(userID uuid.UUID, dateStr string) (*database.DailySteps, error) {
    date, err := time.Parse("2006-01-02", dateStr)
    if err != nil {
        return nil, ErrInvalidDate
    }

    var record database.DailySteps
    err = s.db.Where("user_id = ? AND date = ?", userID, date).First(&record).Error
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return nil, nil // Tidak ada data — kembalikan nil, bukan error
    }
    return &record, err
}