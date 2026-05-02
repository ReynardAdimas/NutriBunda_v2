package main

import (
	"log"
	"nutribunda-backend/configs"
	"nutribunda-backend/internal/auth"
	"nutribunda-backend/internal/database"
	"nutribunda-backend/internal/diary"
	"nutribunda-backend/internal/food"
	"nutribunda-backend/internal/middleware"
	"nutribunda-backend/internal/quiz"
	"nutribunda-backend/internal/recipe"
	"nutribunda-backend/internal/user"
	"nutribunda-backend/internal/currency"

	"github.com/gin-gonic/gin"
)

func main() {
	// Load configuration
	config := configs.LoadConfig()

	// Initialize database connection
	db, err := database.InitDB(config)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Run migrations
	if err := database.RunMigrations(db); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Initialize services
	authService, err := auth.NewService(db, config.JWTSecret, config.JWTExpiration)
	if err != nil {
		log.Fatalf("Failed to initialize auth service: %v", err)
	}

	userService := user.NewService(db, "./uploads")
	foodService := food.NewService(db)
	recipeService := recipe.NewService(db)
	diaryService := diary.NewService(db)
	quizService := quiz.NewService(db)

	// Initialize handlers
	authHandler := auth.NewHandler(authService)
	userHandler := user.NewHandler(userService)
	foodHandler := food.NewHandler(foodService)
	recipeHandler := recipe.NewHandler(recipeService)
	diaryHandler := diary.NewHandler(diaryService)
	quizHandler := quiz.NewHandler(quizService)
	currencyHandler := currency.NewHandler()

	// Initialize Gin router
	router := gin.Default()

	// Apply middleware
	router.Use(middleware.CORS())

	// Serve static files (uploaded images)
	router.Static("/uploads", "./uploads")

	// API routes
	api := router.Group("/api")
	{
		// Health check
		api.GET("/health", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"status":  "ok",
				"message": "NutriBunda API is running",
			})
		})

		// Auth routes (public)
		authRoutes := api.Group("/auth")
		{
			authRoutes.POST("/register", authHandler.Register)
			authRoutes.POST("/login", authHandler.Login)
			authRoutes.POST("/logout", auth.JWTMiddleware(authService), authHandler.Logout)
		}

		// Profile routes (protected)
		profileRoutes := api.Group("/profile")
		profileRoutes.Use(auth.JWTMiddleware(authService))
		{
			profileRoutes.GET("", userHandler.GetProfile)
			profileRoutes.PUT("", userHandler.UpdateProfile)
			profileRoutes.POST("/upload-image", userHandler.UploadProfileImage)
			profileRoutes.DELETE("/image", userHandler.DeleteProfileImage)
		}

		// Food routes (public)
		foodRoutes := api.Group("/foods")
		{
			foodRoutes.GET("", foodHandler.SearchFoods)
			foodRoutes.GET("/sync", foodHandler.SyncFoods)
			foodRoutes.GET("/:id", foodHandler.GetFoodByID)
		}

		// Recipe routes
		recipeRoutes := api.Group("/recipes")
		{
			// Public routes
			recipeRoutes.GET("", recipeHandler.SearchRecipes)
			recipeRoutes.GET("/random", recipeHandler.GetRandomRecipe)
			recipeRoutes.GET("/:id", recipeHandler.GetRecipeByID)

			// Protected routes
			recipeRoutes.GET("/favorites", auth.JWTMiddleware(authService), recipeHandler.GetFavorites)
			recipeRoutes.POST("/:id/favorite", auth.JWTMiddleware(authService), recipeHandler.AddFavorite)
			recipeRoutes.DELETE("/:id/favorite", auth.JWTMiddleware(authService), recipeHandler.RemoveFavorite)
		}

		// Diary routes (protected)
		diaryRoutes := api.Group("/diary")
		diaryRoutes.Use(auth.JWTMiddleware(authService))
		{
			diaryRoutes.POST("", diaryHandler.CreateEntry)
			diaryRoutes.GET("", diaryHandler.GetEntries)
			diaryRoutes.DELETE("/:id", diaryHandler.DeleteEntry)
			diaryRoutes.POST("/sync", diaryHandler.SyncEntries)
			diaryRoutes.POST("/resolve-conflict", diaryHandler.ResolveConflict)
		}

		// Quiz routes (public)
		quizRoutes := api.Group("/quiz")
		{
			quizRoutes.GET("/questions", quizHandler.GetQuestions)
			quizRoutes.POST("/submit", quizHandler.SubmitAnswers)
			quizRoutes.GET("/questions/all", quizHandler.GetAllQuestions) // For admin/testing
		}

		// Currency Routes (public)
		currencyRoutes := api.Group("/currency")
		{
			currencyRoutes.GET("/supported",currencyHandler.GetSupportedCurrencies)
			currencyRoutes.GET("/rate", currencyHandler.GetExchangeRate)
			currencyRoutes.POST("/convert", currencyHandler.ConvertPrice)
		}
	}

	// Start server
	port := config.ServerPort
	if port == "" {
		port = "8080"
	}

	log.Printf("Starting server on port %s...", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
