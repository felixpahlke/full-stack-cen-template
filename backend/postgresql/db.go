//go:generate go run github.com/sqlc-dev/sqlc/cmd/sqlc generate

package postgresql

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
)

func NewPgxPool(postgreURL string, db string) *pgxpool.Pool {
	pgxConfig, err := pgxpool.ParseConfig(postgreURL)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to parse config for db connection")
	}
	pgxConfig.ConnConfig.TLSConfig.InsecureSkipVerify = true
	pgxConfig.ConnConfig.Database = db

	pool, err := pgxpool.NewWithConfig(context.Background(), pgxConfig)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to create db connection")
	}

	if err := pool.Ping(context.Background()); err != nil {
		log.Fatal().Err(err).Msg("failed to ping postgresql")
	}

	return pool
}
