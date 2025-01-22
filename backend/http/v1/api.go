//go:generate go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen -config ./.oapi.codegen/config.yaml ../../docs/openapi.yaml

package v1

import (
	"errors"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.ibm.com/technology-garage-dach/full-stack-cen-template/backend/postgresql"
)

var (
	ErrItemAlreadyExists = errors.New("item already exists")
	ErrItemNotFound      = errors.New("item not found")
)

var _ StrictServerInterface = (*ApiHandler)(nil)

type ApiHandler struct {
	db      *pgxpool.Pool
	querier postgresql.Querier
}

func NewApiHandler(db *pgxpool.Pool) *ApiHandler {
	return &ApiHandler{db: db, querier: postgresql.New()}
}
