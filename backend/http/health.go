package http

import (
	"encoding/json"
	"net/http"
)

var okResult = HealthResult{Status: "ok"}

type HealthResult struct {
	Status string `json:"status"`
}

type HealthHandler struct {
}

func (h HealthHandler) Health() http.HandlerFunc {
	return func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		writer.WriteHeader(http.StatusOK)

		_ = json.NewEncoder(writer).Encode(okResult)
	}
}
