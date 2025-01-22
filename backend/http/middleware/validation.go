package middleware

import (
	"encoding/json"
	"github.com/pb33f/libopenapi"
	libopenapi_validator "github.com/pb33f/libopenapi-validator"
	v1 "github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/http/v1"
	"net/http"
)

type RequestValidationMiddleware struct {
	validator libopenapi_validator.Validator
}

func NewRequestValidationMiddleware(spec *[]byte) (*RequestValidationMiddleware, error) {
	document, err := libopenapi.NewDocument(*spec)
	if err != nil {
		return nil, err
	}
	v, _ := libopenapi_validator.NewValidator(document)
	return &RequestValidationMiddleware{validator: v}, nil
}

func (rvm RequestValidationMiddleware) Handler() func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			requestValid, validationErrors := rvm.validator.ValidateHttpRequest(r)
			if !requestValid {

				violations := make([]v1.Violation, len(validationErrors))
				for _, validationError := range validationErrors {
					for j, violation := range validationError.SchemaValidationErrors {
						violations[j] = v1.Violation{
							Field:   violation.Location,
							Message: violation.Reason,
						}
					}

				}

				violationProblem := v1.ViolationProblem{
					Detail:     http.StatusText(http.StatusUnprocessableEntity),
					Instance:   r.URL.String(),
					Status:     http.StatusUnprocessableEntity,
					Title:      http.StatusText(http.StatusUnprocessableEntity),
					Type:       nil,
					Violations: violations,
				}

				w.Header().Set("Content-Type", "application/problem+json")
				w.WriteHeader(violationProblem.Status)
				json.NewEncoder(w).Encode(violationProblem)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
