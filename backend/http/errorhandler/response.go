package errorhandler

import (
	"encoding/json"
	"errors"
	"github.com/rs/zerolog/log"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/http/v1"
	"net/http"
)

const (
	problemJSONHeaderValue = "application/problem+json"
	contentTypeHeader      = "Content-Type"
)

type ErrorHandlerFunc func(w http.ResponseWriter, r *http.Request, err error)

func ResponseErrorHandler() ErrorHandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, err error) {
		problem := problemForResponseErr(err, r.URL.String())
		w.Header().Set(contentTypeHeader, problemJSONHeaderValue)
		w.WriteHeader(problem.Status)
		_ = json.NewEncoder(w).Encode(problem)
	}
}

func problemForResponseErr(err error, instance string) v1.Problem {
	if errors.Is(err, v1.ErrItemNotFound) {
		return v1.Problem{
			Detail:   err.Error(),
			Instance: instance,
			Status:   http.StatusNotFound,
			Title:    http.StatusText(http.StatusNotFound),
			Type:     nil,
		}
	}

	if errors.Is(err, v1.ErrItemAlreadyExists) {
		return v1.Problem{
			Detail:   err.Error(),
			Instance: instance,
			Status:   http.StatusConflict,
			Title:    http.StatusText(http.StatusConflict),
			Type:     nil,
		}
	}

	log.Info().Err(err).Msg("Handling unmapped error")

	return v1.Problem{
		Detail:   err.Error(),
		Instance: instance,
		Status:   http.StatusInternalServerError,
		Title:    http.StatusText(http.StatusInternalServerError),
		Type:     nil,
	}
}
