package main

import (
	"github.com/rs/cors"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/docs"
	httpserver "github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/http"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/http/errorhandler"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/http/middleware"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/http/v1"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/postgresql"
)

func main() {
	log.Logger = log.With().Caller().Logger()
	zerolog.SetGlobalLevel(zerolog.InfoLevel)

	config := backend.NewApplicationConfig()

	pgx := postgresql.NewPgxPool(
		config.PostgreSQLConfig.URL,
		config.PostgreSQLConfig.Database,
	)
	defer pgx.Close()

	if err := postgresql.MigrateSchema(pgx); err != nil {
		log.Fatal().Err(err).Msg("Failed to migrate schema")
	}

	validationMiddleware, err := middleware.NewJwtValidationMiddleware(
		config.TokenConfig.IssuerURL,
		errorhandler.RequestErrorHandler(),
	)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to create jwt validation middleware")
	}

	requestValidationMiddleware, err := middleware.NewRequestValidationMiddleware(
		&docs.OpenAPISpec,
	)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to create request validation middleware")
	}

	server := httpserver.Server{
		Port:          config.APIConfig.Port,
		BasePath:      config.APIConfig.BasePath,
		V1APIHandler:  v1.NewAPIHandler(pgx),
		V1Middlewares: []v1.MiddlewareFunc{requestValidationMiddleware.Handler(), validationMiddleware.Handler()},
		CorsOptions: cors.Options{
			AllowedOrigins:   config.APIConfig.CORSAllowedOrigins,
			AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
			AllowedHeaders:   []string{"Content-Type", "Authorization"},
			AllowCredentials: true,
		},
	}

	server.Start()
}
