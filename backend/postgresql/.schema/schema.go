package _schema

import "embed"

//go:embed v1/schema.sql
var Schema embed.FS
