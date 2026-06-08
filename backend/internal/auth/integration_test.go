// package auth_test

// import (
// 	"bytes"
// 	"encoding/json"
// 	"net/http"
// 	"net/http/httptest"
// 	"nutribunda-backend/internal/auth"
// 	"nutribunda-backend/internal/database"
// 	"testing"

// 	"github.com/gin-gonic/gin"
// 	"github.com/stretchr/testify/assert"
// 	"github.com/stretchr/testify/require"
// 	"gorm.io/driver/sqlite"
// 	"gorm.io/gorm"
// )

// func setupTestRouter(t *testing.T) (*gin.Engine, *auth.Service, *gorm.DB) {
// 	// Setup test database
// 	dsn := "host=localhost user=nutribunda_user password=nutribunda_pass dbname=nutribunda_test port=5432 sslmode=disable"
// 	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
// 	require.NoError(t, err)

// 	err = db.AutoMigrate(&database.User{})
// 	require.NoError(t, err)

// 	// Clean up
// 	db.Exec("DELETE FROM users")

// 	// Create auth service
// 	authService, err := auth.NewService(db, "test-secret", "24h")
// 	require.NoError(t, err)

// 	// Create handler
// 	authHandler := auth.NewHandler(authService)

// 	// Setup router
// 	gin.SetMode(gin.TestMode)
// 	router := gin.New()

// 	api := router.Group("/api")
// 	{
// 		authRoutes := api.Group("/auth")
// 		{
// 			authRoutes.POST("/register", authHandler.Register)
// 			authRoutes.POST("/login", authHandler.Login)
// 			authRoutes.POST("/logout", auth.JWTMiddleware(authService), authHandler.Logout)
// 		}
// 	}

// 	return router, authService, db
// }

// func TestRegisterEndpoint(t *testing.T) {
// 	router, _, db := setupTestRouter(t)
// 	defer db.Exec("DELETE FROM users")

// 	t.Run("successful registration", func(t *testing.T) {
// 		reqBody := map[string]string{
// 			"email":     "test@example.com",
// 			"password":  "password123",
// 			"full_name": "Test User",
// 		}
// 		body, _ := json.Marshal(reqBody)

// 		req, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(body))
// 		req.Header.Set("Content-Type", "application/json")

// 		w := httptest.NewRecorder()
// 		router.ServeHTTP(w, req)

// 		assert.Equal(t, http.StatusCreated, w.Code)

// 		var response map[string]interface{}
// 		err := json.Unmarshal(w.Body.Bytes(), &response)
// 		require.NoError(t, err)

// 		assert.NotEmpty(t, response["token"])
// 		assert.NotNil(t, response["user"])
// 	})

// 	t.Run("duplicate email", func(t *testing.T) {
// 		reqBody := map[string]string{
// 			"email":     "duplicate@example.com",
// 			"password":  "password123",
// 			"full_name": "Test User",
// 		}
// 		body, _ := json.Marshal(reqBody)

// 		// First registration
// 		req1, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(body))
// 		req1.Header.Set("Content-Type", "application/json")
// 		w1 := httptest.NewRecorder()
// 		router.ServeHTTP(w1, req1)
// 		assert.Equal(t, http.StatusCreated, w1.Code)

// 		// Second registration
// 		req2, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(body))
// 		req2.Header.Set("Content-Type", "application/json")
// 		w2 := httptest.NewRecorder()
// 		router.ServeHTTP(w2, req2)
// 		assert.Equal(t, http.StatusConflict, w2.Code)
// 	})

// 	t.Run("invalid request - missing fields", func(t *testing.T) {
// 		reqBody := map[string]string{
// 			"email": "incomplete@example.com",
// 		}
// 		body, _ := json.Marshal(reqBody)

// 		req, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(body))
// 		req.Header.Set("Content-Type", "application/json")

// 		w := httptest.NewRecorder()
// 		router.ServeHTTP(w, req)

// 		assert.Equal(t, http.StatusBadRequest, w.Code)
// 	})
// }

// func TestLoginEndpoint(t *testing.T) {
// 	router, _, db := setupTestRouter(t)
// 	defer db.Exec("DELETE FROM users")

// 	// Register a user first
// 	registerBody := map[string]string{
// 		"email":     "login@example.com",
// 		"password":  "password123",
// 		"full_name": "Login Test User",
// 	}
// 	body, _ := json.Marshal(registerBody)
// 	req, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(body))
// 	req.Header.Set("Content-Type", "application/json")
// 	w := httptest.NewRecorder()
// 	router.ServeHTTP(w, req)
// 	require.Equal(t, http.StatusCreated, w.Code)

// 	t.Run("successful login", func(t *testing.T) {
// 		loginBody := map[string]string{
// 			"email":    "login@example.com",
// 			"password": "password123",
// 		}
// 		body, _ := json.Marshal(loginBody)

// 		req, _ := http.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(body))
// 		req.Header.Set("Content-Type", "application/json")

// 		w := httptest.NewRecorder()
// 		router.ServeHTTP(w, req)

// 		assert.Equal(t, http.StatusOK, w.Code)

// 		var response map[string]interface{}
// 		err := json.Unmarshal(w.Body.Bytes(), &response)
// 		require.NoError(t, err)

// 		assert.NotEmpty(t, response["token"])
// 		assert.NotNil(t, response["user"])
// 	})

// 	t.Run("invalid credentials", func(t *testing.T) {
// 		loginBody := map[string]string{
// 			"email":    "login@example.com",
// 			"password": "wrongpassword",
// 		}
// 		body, _ := json.Marshal(loginBody)

// 		req, _ := http.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(body))
// 		req.Header.Set("Content-Type", "application/json")

// 		w := httptest.NewRecorder()
// 		router.ServeHTTP(w, req)

// 		assert.Equal(t, http.StatusUnauthorized, w.Code)
// 	})
// }

// func TestLogoutEndpoint(t *testing.T) {
// 	router, _, db := setupTestRouter(t)
// 	defer db.Exec("DELETE FROM users")

// 	// Register and login to get token
// 	registerBody := map[string]string{
// 		"email":     "logout@example.com",
// 		"password":  "password123",
// 		"full_name": "Logout Test User",
// 	}
// 	body, _ := json.Marshal(registerBody)
// 	req, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(body))
// 	req.Header.Set("Content-Type", "application/json")
// 	w := httptest.NewRecorder()
// 	router.ServeHTTP(w, req)
// 	require.Equal(t, http.StatusCreated, w.Code)

// 	var registerResponse map[string]interface{}
// 	json.Unmarshal(w.Body.Bytes(), &registerResponse)
// 	token := registerResponse["token"].(string)

// 	t.Run("successful logout with valid token", func(t *testing.T) {
// 		req, _ := http.NewRequest("POST", "/api/auth/logout", nil)
// 		req.Header.Set("Authorization", "Bearer "+token)

// 		w := httptest.NewRecorder()
// 		router.ServeHTTP(w, req)

// 		assert.Equal(t, http.StatusOK, w.Code)
// 	})

// 	t.Run("logout without token", func(t *testing.T) {
// 		req, _ := http.NewRequest("POST", "/api/auth/logout", nil)

// 		w := httptest.NewRecorder()
// 		router.ServeHTTP(w, req)

// 		assert.Equal(t, http.StatusUnauthorized, w.Code)
// 	})

// 	t.Run("logout with invalid token", func(t *testing.T) {
// 		req, _ := http.NewRequest("POST", "/api/auth/logout", nil)
// 		req.Header.Set("Authorization", "Bearer invalid.token.here")

// 		w := httptest.NewRecorder()
// 		router.ServeHTTP(w, req)

// 		assert.Equal(t, http.StatusUnauthorized, w.Code)
// 	})
// }

// func TestJWTMiddleware(t *testing.T) {
// 	router, _, db := setupTestRouter(t)
// 	defer db.Exec("DELETE FROM users")

// 	// Register to get a valid token
// 	registerBody := map[string]string{
// 		"email":     "middleware@example.com",
// 		"password":  "password123",
// 		"full_name": "Middleware Test User",
// 	}
// 	body, _ := json.Marshal(registerBody)
// 	req, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(body))
// 	req.Header.Set("Content-Type", "application/json")
// 	w := httptest.NewRecorder()
// 	router.ServeHTTP(w, req)
// 	require.Equal(t, http.StatusCreated, w.Code)

// 	var registerResponse map[string]interface{}
// 	json.Unmarshal(w.Body.Bytes(), &registerResponse)
// 	validToken := registerResponse["token"].(string)

// 	testCases := []struct {
// 		name           string
// 		authHeader     string
// 		expectedStatus int
// 	}{
// 		{
// 			name:           "valid token",
// 			authHeader:     "Bearer " + validToken,
// 			expectedStatus: http.StatusOK,
// 		},
// 		{
// 			name:           "missing authorization header",
// 			authHeader:     "",
// 			expectedStatus: http.StatusUnauthorized,
// 		},
// 		{
// 			name:           "invalid format - no Bearer prefix",
// 			authHeader:     validToken,
// 			expectedStatus: http.StatusUnauthorized,
// 		},
// 		{
// 			name:           "invalid token",
// 			authHeader:     "Bearer invalid.token.here",
// 			expectedStatus: http.StatusUnauthorized,
// 		},
// 		{
// 			name:           "empty token",
// 			authHeader:     "Bearer ",
// 			expectedStatus: http.StatusUnauthorized,
// 		},
// 	}

// 	for _, tc := range testCases {
// 		t.Run(tc.name, func(t *testing.T) {
// 			req, _ := http.NewRequest("POST", "/api/auth/logout", nil)
// 			if tc.authHeader != "" {
// 				req.Header.Set("Authorization", tc.authHeader)
// 			}

// 			w := httptest.NewRecorder()
// 			router.ServeHTTP(w, req)

// 			assert.Equal(t, tc.expectedStatus, w.Code)
// 		})
// 	}
// }
