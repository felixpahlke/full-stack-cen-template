package postgresql

import (
	"context"
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
	"github.com/z0ne-dev/mgx/v2"
	_schema "github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/postgresql/.schema"
)

// migrateSchema migrates the database schema using the provided pgxpool.Pool.
func MigrateSchema(pool *pgxpool.Pool) error {
	migrator, _ := mgx.New(
		mgx.Migrations(
			mgx.NewMigration("migrate required v1 schemas for the application", func(ctx context.Context, commands mgx.Commands) error {
				file, err := _schema.Schema.ReadFile("v1/schema.sql")
				if err != nil {
					return fmt.Errorf("failed to read v1/schema.sql: %w", err)
				}
				_, err = commands.Exec(ctx, string(file))
				if err != nil {
					return fmt.Errorf("failed to execute v1/schema.sql: %w", err)
				}
				return nil
			}),
		),
		mgx.Log(logAdapter{}))

	if err := migrator.Migrate(context.Background(), pool); err != nil {
		return fmt.Errorf("failed run migration: %w", err)
	}

	return nil
}

var _ mgx.Logger = (*logAdapter)(nil)

type logAdapter struct{}

func (l logAdapter) Log(msg string, data map[string]any) {

	var formattedData []interface{}
	for key, value := range data {
		formattedData = append(formattedData, fmt.Sprintf("%s: %v", key, value))
	}
	log.Info().Msgf("%s %s", msg, formattedData)
}
