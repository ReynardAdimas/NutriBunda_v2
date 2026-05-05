package user

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/jpeg"
	"image/png"
	"io"
	"mime/multipart"
	"nutribunda-backend/internal/database"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/nfnt/resize"
	"gorm.io/gorm"
)

var (
	ErrUserNotFound       = errors.New("user not found")
	ErrInvalidWeight      = errors.New("weight must be between 30 and 200 kg")
	ErrInvalidHeight      = errors.New("height must be between 100 and 250 cm")
	ErrInvalidImageFormat = errors.New("invalid image format, only JPEG and PNG are supported")
	ErrImageTooLarge      = errors.New("image size exceeds 10MB limit")
)

const (
	MaxImageSize      = 10 * 1024 * 1024 // 10MB
	CompressedMaxSize = 500 * 1024       // 500KB
	ImageWidth        = 800               // Max width for compressed image
)

// Service handles user profile operations
type Service struct {
	db              *gorm.DB
	uploadDirectory string
}

// NewService creates a new user service
func NewService(db *gorm.DB, uploadDirectory string) *Service {
	// Create upload directory if it doesn't exist
	if err := os.MkdirAll(uploadDirectory, 0755); err != nil {
		panic(fmt.Sprintf("Failed to create upload directory: %v", err))
	}

	return &Service{
		db:              db,
		uploadDirectory: uploadDirectory,
	}
}

// UpdateProfileRequest represents profile update request
type UpdateProfileRequest struct {
	FullName        *string  `json:"full_name"`
	Weight          *float64 `json:"weight"`
	Height          *float64 `json:"height"`
	Age             *int     `json:"age"`
	IsBreastfeeding *bool    `json:"is_breastfeeding"`
	ActivityLevel   *string  `json:"activity_level"`
	Timezone        *string  `json:"timezone"`
	BabyBirthDate   *string  `json:"baby_birth_date"`  // format: "YYYY-MM-DD"
	BabyWeightKg    *float64 `json:"baby_weight_kg"`
}

// GetProfile retrieves user profile by ID
func (s *Service) GetProfile(userID uuid.UUID) (*database.User, error) {
	var user database.User
	if err := s.db.Where("id = ?", userID).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &user, nil
}

// UpdateProfile updates user profile information
func (s *Service) UpdateProfile(userID uuid.UUID, req *UpdateProfileRequest) (*database.User, error) {
	// Validate weight if provided
	if req.Weight != nil {
		if *req.Weight < 30 || *req.Weight > 200 {
			return nil, ErrInvalidWeight
		}
	}

	// Validate height if provided
	if req.Height != nil {
		if *req.Height < 100 || *req.Height > 250 {
			return nil, ErrInvalidHeight
		}
	}

	// Validate activity level if provided
	if req.ActivityLevel != nil {
		validLevels := map[string]bool{
			"sedentary":        true,
			"lightly_active":   true,
			"moderately_active": true,
		}
		if !validLevels[*req.ActivityLevel] {
			return nil, errors.New("invalid activity level")
		}
	}

	// Validate timezone if provided
	if req.Timezone != nil {
		validTimezones := map[string]bool{
			"WIB":    true,
			"WITA":   true,
			"WIT":    true,
			"London": true,
		}
		if !validTimezones[*req.Timezone] {
			return nil, errors.New("invalid timezone, must be WIB, WITA, WIT, or London")
		}
	}

	// Get existing user
	var user database.User
	if err := s.db.Where("id = ?", userID).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	// Update fields
	updates := make(map[string]interface{})
	if req.FullName != nil {
		updates["full_name"] = *req.FullName
	}
	if req.Weight != nil {
		updates["weight"] = *req.Weight
	}
	if req.Height != nil {
		updates["height"] = *req.Height
	}
	if req.Age != nil {
		updates["age"] = *req.Age
	}
	if req.IsBreastfeeding != nil {
		updates["is_breastfeeding"] = *req.IsBreastfeeding
	}
	if req.ActivityLevel != nil {
		updates["activity_level"] = *req.ActivityLevel
	}
	if req.Timezone != nil {
		updates["timezone"] = *req.Timezone
	}
	if req.BabyBirthDate != nil {
		if *req.BabyBirthDate == "" {
			updates["baby_birth_date"] = nil
		} else {
			parsed, err := time.Parse("2006-01-02", *req.BabyBirthDate)
			if err != nil {
				return nil, errors.New("invalid baby_birth_date format, use YYYY-MM-DD")
			}
			updates["baby_birth_date"] = parsed
		}
	}
	if req.BabyWeightKg != nil {
		if *req.BabyWeightKg < 2 || *req.BabyWeightKg > 30 {
			return nil, errors.New("baby weight must be between 2 and 30 kg")
		}
		updates["baby_weight_kg"] = *req.BabyWeightKg
	}

	// Update user
	if err := s.db.Model(&user).Updates(updates).Error; err != nil {
		return nil, err
	}

	// Reload user to get updated data
	if err := s.db.Where("id = ?", userID).First(&user).Error; err != nil {
		return nil, err
	}

	return &user, nil
}

// UploadProfileImage uploads and compresses a profile image
func (s *Service) UploadProfileImage(userID uuid.UUID, fileHeader *multipart.FileHeader) (*database.User, error) {
	// Check file size
	if fileHeader.Size > MaxImageSize {
		return nil, ErrImageTooLarge
	}

	// Open uploaded file
	file, err := fileHeader.Open()
	if err != nil {
		return nil, err
	}
	defer file.Close()

	// Read file content
	fileBytes, err := io.ReadAll(file)
	if err != nil {
		return nil, err
	}

	// Detect image format
	contentType := fileHeader.Header.Get("Content-Type")
	var img image.Image
	var ext string

	switch contentType {
	case "image/jpeg", "image/jpg":
		img, err = jpeg.Decode(bytes.NewReader(fileBytes))
		ext = ".jpg"
	case "image/png":
		img, err = png.Decode(bytes.NewReader(fileBytes))
		ext = ".png"
	default:
		return nil, ErrInvalidImageFormat
	}

	if err != nil {
		return nil, fmt.Errorf("failed to decode image: %w", err)
	}

	// Resize image if needed
	bounds := img.Bounds()
	if bounds.Dx() > ImageWidth {
		img = resize.Resize(ImageWidth, 0, img, resize.Lanczos3)
	}

	// Generate unique filename
	filename := fmt.Sprintf("%s%s", uuid.New().String(), ext)
	filepath := filepath.Join(s.uploadDirectory, filename)

	// Create output file
	outFile, err := os.Create(filepath)
	if err != nil {
		return nil, err
	}
	defer outFile.Close()

	// Compress and save image
	if ext == ".jpg" {
		// Try different quality levels to achieve target size
		for quality := 85; quality >= 50; quality -= 10 {
			var buf bytes.Buffer
			if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: quality}); err != nil {
				return nil, err
			}

			if buf.Len() <= CompressedMaxSize || quality == 50 {
				if _, err := outFile.Write(buf.Bytes()); err != nil {
					return nil, err
				}
				break
			}
		}
	} else {
		// PNG encoding
		if err := png.Encode(outFile, img); err != nil {
			return nil, err
		}
	}

	// Update user profile with image URL
	imageURL := "/uploads/" + filename
	var user database.User
	if err := s.db.Model(&user).Where("id = ?", userID).Update("profile_image_url", imageURL).Error; err != nil {
		// Clean up uploaded file if database update fails
		os.Remove(filepath)
		return nil, err
	}

	// Reload user
	if err := s.db.Where("id = ?", userID).First(&user).Error; err != nil {
		return nil, err
	}

	return &user, nil
}

// DeleteProfileImage deletes the user's profile image
func (s *Service) DeleteProfileImage(userID uuid.UUID) error {
	var user database.User
	if err := s.db.Where("id = ?", userID).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrUserNotFound
		}
		return err
	}

	// Delete file if exists
	if user.ProfileImageURL != nil && *user.ProfileImageURL != "" {
		filename := strings.TrimPrefix(*user.ProfileImageURL, "/uploads/")
		filepath := filepath.Join(s.uploadDirectory, filename)
		os.Remove(filepath) // Ignore error if file doesn't exist
	}

	// Update database
	if err := s.db.Model(&user).Update("profile_image_url", nil).Error; err != nil {
		return err
	}

	return nil
}