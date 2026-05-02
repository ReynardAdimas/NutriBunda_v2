package currency

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// Handler handles HTTP requests for currency operations
type Handler struct {
	httpClient *http.Client
}

// NewHandler creates a new currency handler
func NewHandler() *Handler {
	return &Handler{
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// frankfurterResponse is the response shape from frankfurter.app
type frankfurterResponse struct {
	Amount float64            `json:"amount"`
	Base   string             `json:"base"`
	Date   string             `json:"date"`
	Rates  map[string]float64 `json:"rates"`
}

// ConvertPriceRequest represents currency conversion request
type ConvertPriceRequest struct {
	AmountIDR float64 `json:"amount_idr" binding:"required,gt=0"`
	TargetCurrency string `json:"target_currency" binding:"required"`
}

// ConvertPriceResponse is the conversion result
type ConvertPriceResponse struct {
	AmountIDR      float64 `json:"amount_idr"`
	TargetCurrency string  `json:"target_currency"`
	ConvertedAmount float64 `json:"converted_amount"`
	Rate           float64 `json:"rate"`
	Date           string  `json:"date"`
}

// GetSupportedCurrencies returns the list of supported currencies
// @Summary Get supported currencies
// @Description Returns the list of supported currencies from Frankfurter API
// @Tags currency
// @Produce json
// @Success 200 {object} map[string]string
// @Failure 502 {object} map[string]interface{}
// @Router /api/currency/supported [get]
func (h *Handler) GetSupportedCurrencies(c *gin.Context) {
	resp, err := h.httpClient.Get("https://api.frankfurter.app/currencies")
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Failed to fetch currency list"})
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read currency response"})
		return
	}

	var currencies map[string]string
	if err := json.Unmarshal(body, &currencies); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse currency response"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"currencies": currencies})
}

// GetExchangeRate returns the current IDR to target currency rate
// @Summary Get exchange rate
// @Description Get exchange rate from IDR to target currency using Frankfurter API (free, no API key)
// @Tags currency
// @Produce json
// @Param target query string true "Target currency code (e.g. USD, EUR, SGD)"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 502 {object} map[string]interface{}
// @Router /api/currency/rate [get]
func (h *Handler) GetExchangeRate(c *gin.Context) {
	target := c.Query("target")
	if target == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "target currency is required"})
		return
	}

	// Frankfurter does not support IDR as base directly, so we convert:
	// IDR -> EUR (base) then EUR -> target
	// OR: Get USD -> IDR rate and invert
	// Use latest endpoint: GET /latest?from=IDR&to=USD (but IDR not supported as base)
	// Workaround: use USD as base, get IDR rate, then compute IDR->target
	url := fmt.Sprintf("https://api.frankfurter.app/latest?from=USD&to=IDR,%s", target)
	resp, err := h.httpClient.Get(url)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Failed to fetch exchange rate"})
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read rate response"})
		return
	}

	var result frankfurterResponse
	if err := json.Unmarshal(body, &result); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse rate response"})
		return
	}

	idrRate, hasIDR := result.Rates["IDR"]
	targetRate, hasTarget := result.Rates[target]

	if !hasIDR {
		c.JSON(http.StatusBadGateway, gin.H{"error": "IDR rate not available"})
		return
	}
	if !hasTarget {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": fmt.Sprintf("Currency %s not supported", target),
		})
		return
	}

	// Rate: 1 IDR = ? target
	// USD -> IDR = idrRate  => 1 IDR = 1/idrRate USD
	// USD -> target = targetRate => 1 USD = targetRate target
	// So: 1 IDR = targetRate/idrRate target
	rateIDRToTarget := targetRate / idrRate

	c.JSON(http.StatusOK, gin.H{
		"base":             "IDR",
		"target":           target,
		"rate":             rateIDRToTarget,
		"date":             result.Date,
		"source":           "frankfurter.app",
	})
}

// ConvertPrice converts an IDR price to target currency
// @Summary Convert price from IDR
// @Description Convert food price from IDR to target currency
// @Tags currency
// @Accept json
// @Produce json
// @Param body body ConvertPriceRequest true "Conversion request"
// @Success 200 {object} ConvertPriceResponse
// @Failure 400 {object} map[string]interface{}
// @Failure 502 {object} map[string]interface{}
// @Router /api/currency/convert [post]
func (h *Handler) ConvertPrice(c *gin.Context) {
	var req ConvertPriceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request", "details": err.Error()})
		return
	}

	url := fmt.Sprintf("https://api.frankfurter.app/latest?from=USD&to=IDR,%s", req.TargetCurrency)
	resp, err := h.httpClient.Get(url)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Failed to fetch exchange rate"})
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read rate response"})
		return
	}

	var result frankfurterResponse
	if err := json.Unmarshal(body, &result); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse rate response"})
		return
	}

	idrRate, hasIDR := result.Rates["IDR"]
	targetRate, hasTarget := result.Rates[req.TargetCurrency]

	if !hasIDR || !hasTarget {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Currency %s not supported", req.TargetCurrency)})
		return
	}

	rateIDRToTarget := targetRate / idrRate
	converted := req.AmountIDR * rateIDRToTarget

	c.JSON(http.StatusOK, ConvertPriceResponse{
		AmountIDR:       req.AmountIDR,
		TargetCurrency:  req.TargetCurrency,
		ConvertedAmount: converted,
		Rate:            rateIDRToTarget,
		Date:            result.Date,
	})
}