package middleware

import (
	"errors"
	"fmt"
	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/ctx"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	BearerTokenPrefix      = "Bearer "
	AuthorizationHeaderKey = "Authorization"
)

var (
	ErrUnauthorized = errors.New("unauthorized")
	ErrForbidden    = errors.New("forbidden")
)

type JwtValidationMiddleware struct {
	issuer       string
	kFunc        keyfunc.Keyfunc
	errorHandler func(w http.ResponseWriter, r *http.Request, err error)
}

func NewJwtValidationMiddleware(issuerURL string, errorHandler func(w http.ResponseWriter, r *http.Request, err error)) (*JwtValidationMiddleware, error) {
	jwksPath, err := url.JoinPath(issuerURL, "/publickeys")
	if err != nil {
		return nil, fmt.Errorf("could create jwks path: %w", err)
	}

	kFunc, err := keyfunc.NewDefault([]string{jwksPath})
	if err != nil {
		return nil, fmt.Errorf("could not load jwks: %w", err)
	}
	return &JwtValidationMiddleware{
		issuer:       issuerURL,
		kFunc:        kFunc,
		errorHandler: errorHandler,
	}, nil
}

type AppIDClaims struct {
	jwt.RegisteredClaims
	Email string `json:"email"`
	Sub   string `json:"sub"`
}

func (middleware *JwtValidationMiddleware) Handler() func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

			header := r.Header.Get(AuthorizationHeaderKey)
			if header == "" || !strings.HasPrefix(header, BearerTokenPrefix) {
				middleware.errorHandler(w, r, ErrUnauthorized)
				return
			}

			tokenString := strings.TrimPrefix(header, BearerTokenPrefix)

			var claims AppIDClaims

			token, err := jwt.ParseWithClaims(tokenString, &claims, middleware.kFunc.Keyfunc,
				jwt.WithValidMethods([]string{jwt.SigningMethodRS256.Alg()}),
				jwt.WithIssuer(middleware.issuer),
				jwt.WithLeeway(time.Minute*2),
			)
			if err != nil {
				middleware.errorHandler(w, r, ErrForbidden)
			}

			if !token.Valid {
				middleware.errorHandler(w, r, ErrForbidden)
			}

			user := ctx.User{
				ID:    uuid.MustParse(claims.Sub),
				Email: claims.Email,
			}
			next.ServeHTTP(w, r.WithContext(ctx.CreateUserContext(r.Context(), user)))
		})
	}
}
