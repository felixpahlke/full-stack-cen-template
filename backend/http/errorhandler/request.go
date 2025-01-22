package errorhandler

import (
	"encoding/json"
	"errors"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/http/middleware"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/http/v1"
	"net/http"
)

func RequestErrorHandler() ErrorHandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, err error) {
		problem := problemForRequestErr(err, r.URL.String())

		w.Header().Set(contentTypeHeader, problemJsonHeaderValue)
		w.WriteHeader(problem.Status)
		json.NewEncoder(w).Encode(problem)
	}
}

func problemForRequestErr(err error, instance string) v1.Problem {
	if errors.Is(err, middleware.ErrUnauthorized) {
		return v1.Problem{
			Detail:   http.StatusText(http.StatusUnauthorized),
			Instance: instance,
			Status:   http.StatusUnauthorized,
			Title:    http.StatusText(http.StatusUnauthorized),
			Type:     nil,
		}
	}

	if errors.Is(err, middleware.ErrForbidden) {
		return v1.Problem{
			Detail:   http.StatusText(http.StatusForbidden),
			Instance: instance,
			Status:   http.StatusForbidden,
			Title:    http.StatusText(http.StatusForbidden),
			Type:     nil,
		}
	}

	return v1.Problem{
		Detail:   err.Error(),
		Instance: instance,
		Status:   http.StatusBadRequest,
		Title:    http.StatusText(http.StatusBadRequest),
		Type:     nil,
	}
}
