package http

import (
	"context"
	"errors"
	"fmt"
	"github.com/rs/zerolog/log"
	"github.com/swaggest/swgui/v5emb"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/docs"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/http/errorhandler"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/http/v1"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func Start(port int, basePath string, apiHandler *v1.ApiHandler, middlewares ...v1.MiddlewareFunc) {
	serveMux := http.NewServeMux()

	serveMux.HandleFunc("GET /openapi.yaml", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/yaml")
		w.WriteHeader(http.StatusOK)
		w.Write(docs.OpenAPISpec)
	})

	serveMux.Handle("GET /swagger-ui/", v5emb.New("swagger-ui", "/openapi.yaml", "/swagger-ui/"))

	opsHandler := HealthHandler{}

	serveMux.Handle("GET /healthz", opsHandler.Health())

	v1.HandlerWithOptions(
		v1.NewStrictHandlerWithOptions(
			apiHandler,
			nil,
			v1.StrictHTTPServerOptions{
				RequestErrorHandlerFunc:  errorhandler.RequestErrorHandler(),
				ResponseErrorHandlerFunc: errorhandler.ResponseErrorHandler(),
			},
		),
		v1.StdHTTPServerOptions{
			BaseURL:     basePath,
			BaseRouter:  serveMux,
			Middlewares: middlewares,
		},
	)

	server := http.Server{
		Addr:         fmt.Sprintf(":%d", port),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 5 * time.Second,
		Handler:      serveMux,
	}

	go func() {
		log.Info().Msgf("Starting server on %s", server.Addr)
		if err := server.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
			log.Fatal().Err(err).Msg("error starting server")
		}
		log.Info().Msg("Stopped serving new connections")
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	shutdownCtx, shutdownRelease := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownRelease()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Fatal().Err(err).Msg("HTTP shutdown error")
	}
	log.Info().Msg("Graceful shutdown complete")
}
