//go:build tools
// +build tools

package main

import (
	_ "github.com/air-verse/air"
	_ "github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen"
	_ "github.com/sqlc-dev/sqlc/cmd/sqlc"
)
