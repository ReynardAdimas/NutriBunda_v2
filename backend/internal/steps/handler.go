package steps

import (
    "net/http"
    "nutribunda-backend/internal/auth"

    "github.com/gin-gonic/gin"
)

type Handler struct {
    service *Service
}

func NewHandler(service *Service) *Handler {
    return &Handler{service: service}
}

// UpsertSteps godoc
// @Summary Save or update daily steps
// @Router /api/steps [post]
func (h *Handler) UpsertSteps(c *gin.Context) {
    userID, err := auth.GetUserID(c)
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
        return
    }

    var req UpsertStepsRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request", "details": err.Error()})
        return
    }

    record, err := h.service.UpsertDailySteps(userID, &req)
    if err != nil {
        if err == ErrInvalidDate {
            c.JSON(http.StatusBadRequest, gin.H{"error": "Format tanggal tidak valid, gunakan YYYY-MM-DD"})
            return
        }
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menyimpan data langkah"})
        return
    }

    c.JSON(http.StatusOK, record)
}

// GetSteps godoc
// @Summary Get daily steps for a date
// @Router /api/steps [get]
func (h *Handler) GetSteps(c *gin.Context) {
    userID, err := auth.GetUserID(c)
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
        return
    }

    date := c.Query("date")
    if date == "" {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Parameter 'date' diperlukan"})
        return
    }

    record, err := h.service.GetDailySteps(userID, date)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal mengambil data langkah"})
        return
    }

    if record == nil {
        c.JSON(http.StatusOK, gin.H{"steps": 0, "calories_burned": 0.0, "date": date})
        return
    }

    c.JSON(http.StatusOK, record)
}