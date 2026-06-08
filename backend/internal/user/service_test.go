package user

import (
	"bytes"
	"image"
	"image/jpeg"
	"image/png"
	"io"
	"mime/multipart"
	"nutribunda-backend/internal/database"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// setupTestDB creates a test database connection
func setupTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	require.NoError(t, err)

	err = db.AutoMigrate(&database.User{})
	require.NoError(t, err)

	return db
}

// cleanupTestDB cleans up test data
func cleanupTestDB(t *testing.T, db *gorm.DB) {
	db.Exec("DELETE FROM users")
}

// createTestUser creates a test user in the database
func createTestUser(t *testing.T, db *gorm.DB) *database.User {
	user := &database.User{
		Email:        "test@example.com",
		PasswordHash: "hashedpassword",
		FullName:     "Test User",
		Timezone:     "WIB",
	}
	err := db.Create(user).Error
	require.NoError(t, err)
	return user
}

func TestNewService(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)

	uploadDir := "./test_uploads"
	defer os.RemoveAll(uploadDir)

	service := NewService(db, uploadDir)
	assert.NotNil(t, service)

	// Verify upload directory was created
	_, err := os.Stat(uploadDir)
	assert.NoError(t, err)
}

func TestGetProfile(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)

	service := NewService(db, "./test_uploads")
	user := createTestUser(t, db)

	t.Run("existing user", func(t *testing.T) {
		profile, err := service.GetProfile(user.ID)
		require.NoError(t, err)
		assert.Equal(t, user.ID, profile.ID)
		assert.Equal(t, user.Email, profile.Email)
		assert.Equal(t, user.FullName, profile.FullName)
	})

	t.Run("non-existent user", func(t *testing.T) {
		_, err := service.GetProfile(uuid.New())
		assert.ErrorIs(t, err, ErrUserNotFound)
	})
}

func TestUpdateProfile(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)

	service := NewService(db, "./test_uploads")
	user := createTestUser(t, db)

	t.Run("update full name", func(t *testing.T) {
		newName := "Updated Name"
		req := &UpdateProfileRequest{
			FullName: &newName,
		}

		updatedUser, err := service.UpdateProfile(user.ID, req)
		require.NoError(t, err)
		assert.Equal(t, newName, updatedUser.FullName)
	})

	t.Run("update weight - valid", func(t *testing.T) {
		weight := 65.5
		req := &UpdateProfileRequest{
			Weight: &weight,
		}

		updatedUser, err := service.UpdateProfile(user.ID, req)
		require.NoError(t, err)
		assert.NotNil(t, updatedUser.Weight)
		assert.Equal(t, weight, *updatedUser.Weight)
	})

	t.Run("update weight - too low", func(t *testing.T) {
		weight := 25.0
		req := &UpdateProfileRequest{
			Weight: &weight,
		}

		_, err := service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidWeight)
	})

	t.Run("update weight - too high", func(t *testing.T) {
		weight := 250.0
		req := &UpdateProfileRequest{
			Weight: &weight,
		}

		_, err := service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidWeight)
	})

	t.Run("update height - valid", func(t *testing.T) {
		height := 165.0
		req := &UpdateProfileRequest{
			Height: &height,
		}

		updatedUser, err := service.UpdateProfile(user.ID, req)
		require.NoError(t, err)
		assert.NotNil(t, updatedUser.Height)
		assert.Equal(t, height, *updatedUser.Height)
	})

	t.Run("update height - too low", func(t *testing.T) {
		height := 90.0
		req := &UpdateProfileRequest{
			Height: &height,
		}

		_, err := service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidHeight)
	})

	t.Run("update height - too high", func(t *testing.T) {
		height := 260.0
		req := &UpdateProfileRequest{
			Height: &height,
		}

		_, err := service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidHeight)
	})

	t.Run("update activity level - valid", func(t *testing.T) {
		activityLevel := "lightly_active"
		req := &UpdateProfileRequest{
			ActivityLevel: &activityLevel,
		}

		updatedUser, err := service.UpdateProfile(user.ID, req)
		require.NoError(t, err)
		assert.Equal(t, activityLevel, updatedUser.ActivityLevel)
	})

	t.Run("update activity level - invalid", func(t *testing.T) {
		activityLevel := "super_active"
		req := &UpdateProfileRequest{
			ActivityLevel: &activityLevel,
		}

		_, err := service.UpdateProfile(user.ID, req)
		assert.Error(t, err)
	})

	t.Run("update timezone - valid", func(t *testing.T) {
		timezone := "WITA"
		req := &UpdateProfileRequest{
			Timezone: &timezone,
		}

		updatedUser, err := service.UpdateProfile(user.ID, req)
		require.NoError(t, err)
		assert.Equal(t, timezone, updatedUser.Timezone)
	})

	t.Run("update timezone - invalid", func(t *testing.T) {
		timezone := "PST"
		req := &UpdateProfileRequest{
			Timezone: &timezone,
		}

		_, err := service.UpdateProfile(user.ID, req)
		assert.Error(t, err)
	})

	t.Run("update multiple fields", func(t *testing.T) {
		newName := "Multi Update"
		weight := 70.0
		height := 170.0
		age := 30
		isBreastfeeding := true

		req := &UpdateProfileRequest{
			FullName:        &newName,
			Weight:          &weight,
			Height:          &height,
			Age:             &age,
			IsBreastfeeding: &isBreastfeeding,
		}

		updatedUser, err := service.UpdateProfile(user.ID, req)
		require.NoError(t, err)
		assert.Equal(t, newName, updatedUser.FullName)
		assert.Equal(t, weight, *updatedUser.Weight)
		assert.Equal(t, height, *updatedUser.Height)
		assert.Equal(t, age, *updatedUser.Age)
		assert.Equal(t, isBreastfeeding, updatedUser.IsBreastfeeding)
	})
}

func TestUploadProfileImage(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)

	uploadDir := "./test_uploads"
	defer os.RemoveAll(uploadDir)

	service := NewService(db, uploadDir)
	user := createTestUser(t, db)

	// Create a test JPEG image
	createTestImage := func() *multipart.FileHeader {
		// Create a simple test image
		img := image.NewRGBA(image.Rect(0, 0, 100, 100))

		// Encode to JPEG
		var buf bytes.Buffer
		err := jpeg.Encode(&buf, img, nil)
		require.NoError(t, err)

		// Create multipart file header
		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		part, err := writer.CreateFormFile("image", "test.jpg")
		require.NoError(t, err)

		_, err = io.Copy(part, &buf)
		require.NoError(t, err)
		writer.Close()

		// Parse the multipart form
		reader := multipart.NewReader(body, writer.Boundary())
		form, err := reader.ReadForm(10 << 20)
		require.NoError(t, err)

		fileHeader := form.File["image"][0]
		// Set Content-Type header for JPEG
		fileHeader.Header.Set("Content-Type", "image/jpeg")

		return fileHeader
	}

	t.Run("successful upload", func(t *testing.T) {
		fileHeader := createTestImage()

		updatedUser, err := service.UploadProfileImage(user.ID, fileHeader)
		require.NoError(t, err)
		assert.NotNil(t, updatedUser.ProfileImageURL)
		assert.Contains(t, *updatedUser.ProfileImageURL, "/uploads/")
	})
}

// Property-based test: Profile validation consistency
func TestProfileValidationConsistency(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)

	service := NewService(db, "./test_uploads")

	testCases := []struct {
		name          string
		weight        float64
		height        float64
		shouldSucceed bool
	}{
		{"valid_min_weight", 30.0, 150.0, true},
		{"valid_max_weight", 200.0, 150.0, true},
		{"valid_mid_weight", 65.5, 165.0, true},
		{"invalid_low_weight", 29.9, 150.0, false},
		{"invalid_high_weight", 200.1, 150.0, false},
		{"valid_min_height", 65.0, 100.0, true},
		{"valid_max_height", 65.0, 250.0, true},
		{"valid_mid_height", 65.0, 165.0, true},
		{"invalid_low_height", 65.0, 99.9, false},
		{"invalid_high_height", 65.0, 250.1, false},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			user := createTestUser(t, db)
			defer db.Delete(user)

			req := &UpdateProfileRequest{
				Weight: &tc.weight,
				Height: &tc.height,
			}

			_, err := service.UpdateProfile(user.ID, req)

			if tc.shouldSucceed {
				assert.NoError(t, err, "Expected validation to succeed for %s", tc.name)
			} else {
				assert.Error(t, err, "Expected validation to fail for %s", tc.name)
			}
		})
	}
}

// TestProfileDataValidation tests profile data validation according to Requirements 12.4 and 12.5
func TestProfileDataValidation(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)

	service := NewService(db, "./test_uploads")

	t.Run("weight validation - boundary values", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Test minimum valid weight (30 kg)
		weight := 30.0
		req := &UpdateProfileRequest{Weight: &weight}
		_, err := service.UpdateProfile(user.ID, req)
		assert.NoError(t, err, "Weight of 30 kg should be valid")

		// Test maximum valid weight (200 kg)
		weight = 200.0
		req = &UpdateProfileRequest{Weight: &weight}
		_, err = service.UpdateProfile(user.ID, req)
		assert.NoError(t, err, "Weight of 200 kg should be valid")

		// Test below minimum (29.9 kg)
		weight = 29.9
		req = &UpdateProfileRequest{Weight: &weight}
		_, err = service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidWeight, "Weight below 30 kg should be invalid")

		// Test above maximum (200.1 kg)
		weight = 200.1
		req = &UpdateProfileRequest{Weight: &weight}
		_, err = service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidWeight, "Weight above 200 kg should be invalid")
	})

	t.Run("height validation - boundary values", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Test minimum valid height (100 cm)
		height := 100.0
		req := &UpdateProfileRequest{Height: &height}
		_, err := service.UpdateProfile(user.ID, req)
		assert.NoError(t, err, "Height of 100 cm should be valid")

		// Test maximum valid height (250 cm)
		height = 250.0
		req = &UpdateProfileRequest{Height: &height}
		_, err = service.UpdateProfile(user.ID, req)
		assert.NoError(t, err, "Height of 250 cm should be valid")

		// Test below minimum (99.9 cm)
		height = 99.9
		req = &UpdateProfileRequest{Height: &height}
		_, err = service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidHeight, "Height below 100 cm should be invalid")

		// Test above maximum (250.1 cm)
		height = 250.1
		req = &UpdateProfileRequest{Height: &height}
		_, err = service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidHeight, "Height above 250 cm should be invalid")
	})

	t.Run("specific error messages for invalid fields", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Test weight error message
		weight := 25.0
		req := &UpdateProfileRequest{Weight: &weight}
		_, err := service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidWeight)
		assert.Contains(t, err.Error(), "weight must be between 30 and 200 kg")

		// Test height error message
		height := 90.0
		req = &UpdateProfileRequest{Height: &height}
		_, err = service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidHeight)
		assert.Contains(t, err.Error(), "height must be between 100 and 250 cm")
	})

	t.Run("combined weight and height validation", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Valid weight and height
		weight := 65.0
		height := 165.0
		req := &UpdateProfileRequest{
			Weight: &weight,
			Height: &height,
		}
		updatedUser, err := service.UpdateProfile(user.ID, req)
		assert.NoError(t, err)
		assert.Equal(t, weight, *updatedUser.Weight)
		assert.Equal(t, height, *updatedUser.Height)

		// Invalid weight, valid height
		weight = 250.0
		height = 165.0
		req = &UpdateProfileRequest{
			Weight: &weight,
			Height: &height,
		}
		_, err = service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidWeight)

		// Valid weight, invalid height
		weight = 65.0
		height = 300.0
		req = &UpdateProfileRequest{
			Weight: &weight,
			Height: &height,
		}
		_, err = service.UpdateProfile(user.ID, req)
		assert.ErrorIs(t, err, ErrInvalidHeight)
	})
}

// TestProfilePhotoUpload tests profile photo upload functionality according to Requirement 12.3
func TestProfilePhotoUpload(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)

	uploadDir := "./test_uploads"
	defer os.RemoveAll(uploadDir)

	service := NewService(db, uploadDir)

	// Helper function to create test image with specific size
	createTestImageWithSize := func(width, height int) *multipart.FileHeader {
		img := image.NewRGBA(image.Rect(0, 0, width, height))

		var buf bytes.Buffer
		err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 90})
		require.NoError(t, err)

		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		part, err := writer.CreateFormFile("image", "test.jpg")
		require.NoError(t, err)

		_, err = io.Copy(part, &buf)
		require.NoError(t, err)
		writer.Close()

		reader := multipart.NewReader(body, writer.Boundary())
		form, err := reader.ReadForm(10 << 20)
		require.NoError(t, err)

		fileHeader := form.File["image"][0]
		// Set Content-Type header for JPEG
		fileHeader.Header.Set("Content-Type", "image/jpeg")

		return fileHeader
	}

	t.Run("successful image upload and compression", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		fileHeader := createTestImageWithSize(1000, 1000)

		updatedUser, err := service.UploadProfileImage(user.ID, fileHeader)
		require.NoError(t, err)
		assert.NotNil(t, updatedUser.ProfileImageURL)
		assert.Contains(t, *updatedUser.ProfileImageURL, "/uploads/")

		// Verify file was created
		filename := strings.TrimPrefix(*updatedUser.ProfileImageURL, "/uploads/")
		filepath := filepath.Join(uploadDir, filename)
		_, err = os.Stat(filepath)
		assert.NoError(t, err, "Uploaded file should exist")

		// Verify file size is under 500KB (compressed)
		fileInfo, err := os.Stat(filepath)
		require.NoError(t, err)
		assert.LessOrEqual(t, fileInfo.Size(), int64(CompressedMaxSize), 
			"Compressed image should be under 500KB")
	})

	t.Run("image format validation - JPEG", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		fileHeader := createTestImageWithSize(500, 500)
		
		updatedUser, err := service.UploadProfileImage(user.ID, fileHeader)
		require.NoError(t, err)
		assert.NotNil(t, updatedUser.ProfileImageURL)
	})

	t.Run("image format validation - PNG", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Create PNG image
		img := image.NewRGBA(image.Rect(0, 0, 500, 500))
		var buf bytes.Buffer
		err := png.Encode(&buf, img)
		require.NoError(t, err)

		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		part, err := writer.CreateFormFile("image", "test.png")
		require.NoError(t, err)
		part.Write(buf.Bytes())
		writer.Close()

		reader := multipart.NewReader(body, writer.Boundary())
		form, err := reader.ReadForm(10 << 20)
		require.NoError(t, err)

		fileHeader := form.File["image"][0]
		fileHeader.Header.Set("Content-Type", "image/png")

		updatedUser, err := service.UploadProfileImage(user.ID, fileHeader)
		require.NoError(t, err)
		assert.NotNil(t, updatedUser.ProfileImageURL)
	})

	t.Run("invalid image format", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Create a text file instead of image
		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		part, err := writer.CreateFormFile("image", "test.txt")
		require.NoError(t, err)
		part.Write([]byte("This is not an image"))
		writer.Close()

		reader := multipart.NewReader(body, writer.Boundary())
		form, err := reader.ReadForm(10 << 20)
		require.NoError(t, err)

		fileHeader := form.File["image"][0]
		fileHeader.Header.Set("Content-Type", "text/plain")

		_, err = service.UploadProfileImage(user.ID, fileHeader)
		assert.ErrorIs(t, err, ErrInvalidImageFormat)
	})

	t.Run("image size limit - exceeds 10MB", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Create a large file header (simulate > 10MB)
		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		part, err := writer.CreateFormFile("image", "large.jpg")
		require.NoError(t, err)
		
		// Write 11MB of data
		largeData := make([]byte, 11*1024*1024)
		part.Write(largeData)
		writer.Close()

		reader := multipart.NewReader(body, writer.Boundary())
		form, err := reader.ReadForm(20 << 20)
		require.NoError(t, err)

		fileHeader := form.File["image"][0]

		_, err = service.UploadProfileImage(user.ID, fileHeader)
		assert.ErrorIs(t, err, ErrImageTooLarge)
	})

	t.Run("replace existing profile image", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Upload first image
		fileHeader1 := createTestImageWithSize(500, 500)
		updatedUser1, err := service.UploadProfileImage(user.ID, fileHeader1)
		require.NoError(t, err)
		firstImageURL := *updatedUser1.ProfileImageURL

		// Upload second image
		fileHeader2 := createTestImageWithSize(600, 600)
		updatedUser2, err := service.UploadProfileImage(user.ID, fileHeader2)
		require.NoError(t, err)
		secondImageURL := *updatedUser2.ProfileImageURL

		// URLs should be different
		assert.NotEqual(t, firstImageURL, secondImageURL)
	})

	t.Run("delete profile image", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Upload image first
		fileHeader := createTestImageWithSize(500, 500)
		updatedUser, err := service.UploadProfileImage(user.ID, fileHeader)
		require.NoError(t, err)
		imageURL := *updatedUser.ProfileImageURL

		// Delete image
		err = service.DeleteProfileImage(user.ID)
		require.NoError(t, err)

		// Verify image URL is cleared
		user, err = service.GetProfile(user.ID)
		require.NoError(t, err)
		assert.Nil(t, user.ProfileImageURL)

		// Verify file is deleted
		filename := strings.TrimPrefix(imageURL, "/uploads/")
		filepath := filepath.Join(uploadDir, filename)
		_, err = os.Stat(filepath)
		assert.True(t, os.IsNotExist(err), "Image file should be deleted")
	})
}

// TestProfileErrorHandling tests error handling for various scenarios
func TestProfileErrorHandling(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)

	service := NewService(db, "./test_uploads")

	t.Run("get profile - user not found", func(t *testing.T) {
		nonExistentID := uuid.New()
		_, err := service.GetProfile(nonExistentID)
		assert.ErrorIs(t, err, ErrUserNotFound)
	})

	t.Run("update profile - user not found", func(t *testing.T) {
		nonExistentID := uuid.New()
		name := "Test"
		req := &UpdateProfileRequest{FullName: &name}
		_, err := service.UpdateProfile(nonExistentID, req)
		assert.ErrorIs(t, err, ErrUserNotFound)
	})

	t.Run("delete profile image - user not found", func(t *testing.T) {
		nonExistentID := uuid.New()
		err := service.DeleteProfileImage(nonExistentID)
		assert.ErrorIs(t, err, ErrUserNotFound)
	})

	t.Run("multiple validation errors", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Invalid weight should be caught first
		weight := 25.0
		height := 300.0
		req := &UpdateProfileRequest{
			Weight: &weight,
			Height: &height,
		}
		_, err := service.UpdateProfile(user.ID, req)
		assert.Error(t, err)
		// Weight validation happens first
		assert.ErrorIs(t, err, ErrInvalidWeight)
	})
}

// TestProfileUpdatePersistence tests that profile updates are persisted correctly
func TestProfileUpdatePersistence(t *testing.T) {
	db := setupTestDB(t)
	defer cleanupTestDB(t, db)

	service := NewService(db, "./test_uploads")

	t.Run("profile data persists after update", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Update profile
		weight := 70.0
		height := 165.0
		age := 28
		isBreastfeeding := true
		activityLevel := "moderately_active"
		timezone := "WITA"

		req := &UpdateProfileRequest{
			Weight:          &weight,
			Height:          &height,
			Age:             &age,
			IsBreastfeeding: &isBreastfeeding,
			ActivityLevel:   &activityLevel,
			Timezone:        &timezone,
		}

		updatedUser, err := service.UpdateProfile(user.ID, req)
		require.NoError(t, err)

		// Retrieve profile again
		retrievedUser, err := service.GetProfile(user.ID)
		require.NoError(t, err)

		// Verify all fields persisted
		assert.Equal(t, weight, *retrievedUser.Weight)
		assert.Equal(t, height, *retrievedUser.Height)
		assert.Equal(t, age, *retrievedUser.Age)
		assert.Equal(t, isBreastfeeding, retrievedUser.IsBreastfeeding)
		assert.Equal(t, activityLevel, retrievedUser.ActivityLevel)
		assert.Equal(t, timezone, retrievedUser.Timezone)
		assert.Equal(t, updatedUser.UpdatedAt, retrievedUser.UpdatedAt)
	})

	t.Run("partial update preserves other fields", func(t *testing.T) {
		user := createTestUser(t, db)
		defer db.Delete(user)

		// Set initial values
		weight := 65.0
		height := 160.0
		req := &UpdateProfileRequest{
			Weight: &weight,
			Height: &height,
		}
		_, err := service.UpdateProfile(user.ID, req)
		require.NoError(t, err)

		// Update only weight
		newWeight := 70.0
		req = &UpdateProfileRequest{
			Weight: &newWeight,
		}
		updatedUser, err := service.UpdateProfile(user.ID, req)
		require.NoError(t, err)

		// Height should remain unchanged
		assert.Equal(t, newWeight, *updatedUser.Weight)
		assert.Equal(t, height, *updatedUser.Height)
	})
}
