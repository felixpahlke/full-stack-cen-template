package backend

import (
	"github.com/caarlos0/env/v11"
	"github.com/joho/godotenv"
	"github.com/rs/zerolog/log"
	"os"
	"path/filepath"
)

type ApplicationConfig struct {
	APIConfig        APIConfig        `envPrefix:"API_"`
	PostgreSQLConfig PostgreSQLConfig `envPrefix:"POSTGRESQL_"`
	TokenConfig      TokenConfig      `envPrefix:"TOKEN_"`
}

type APIConfig struct {
	Port     int    `env:"PORT" envDefault:"8080"`
	BasePath string `env:"BASE_PATH" envDefault:"/api"`
}

type PostgreSQLConfig struct {
	URL      string `env:"URL,notEmpty"`
	Database string `env:"DATABASE,notEmpty"`
}

type TokenConfig struct {
	IssuerURL string `env:"ISSUER_URL,notEmpty"`
}

func NewApplicationConfig() ApplicationConfig {
	err := godotenv.Load(dir(".env"))
	if err != nil {
		log.Info().Err(err).Msg("Error loading .env file")
	}
	var c ApplicationConfig
	if err := env.ParseWithOptions(&c, env.Options{}); err != nil {
		log.Fatal().Err(err).Msg("Failed to load app config")
	}
	return c
}

// dir returns the absolute path of the given environment file (envFile) in the Go module's
// root directory. It searches for the 'go.mod' file from the current working directory upwards
// and appends the envFile to the directory containing 'go.mod'.
// It panics if it fails to find the 'go.mod' file.
func dir(envFile string) string {
	currentDir, err := os.Getwd()
	if err != nil {
		log.Info().Err(err).Msg("Error getting wd")
	}

	for {
		goModPath := filepath.Join(currentDir, "go.mod")
		if _, err := os.Stat(goModPath); err == nil {
			break
		}

		parent := filepath.Dir(currentDir)
		if parent == currentDir {
			log.Info().Err(err).Msg("go.mod not found")
			break
		}
		currentDir = parent
	}

	return filepath.Join(currentDir, envFile)
}
