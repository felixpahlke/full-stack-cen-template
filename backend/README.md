# Backend

This project is a backend implementation built with Go, leveraging modern tools for type safety and code generation. It integrates the following technologies:

- [oapi-codegen](https://github.com/oapi-codegen/oapi-codegen): Generates type-safe API boilerplate from OpenAPI specifications, ensuring consistent and error-free API interactions.  This includes API routes, handlers, and request/response types. After the code is generated, you can use it to implement the actual logic of the API.
- [sqlc](https://sqlc.dev): Generates type-safe Go code from raw SQL statements, offering a robust solution for working with databases in a type-safe manner. sqlc generates Go code from raw SQL queries, making it easy to interact with a database while preserving type safety. The generated code includes functions for executing queries, as well as Go structs representing database models.
- Go 1.23: The project is built using the latest stable release of Go, ensuring high performance and access to the latest language features.

By using these tools, this backend implementation ensures maintainable, reliable, and efficient development workflows, while reducing common issues related to API and database interactions.

## Requirements
- install go using [brew](https://formulae.brew.sh/formula/go) or [manually](https://go.dev/doc/install) 
- install make for using Makefiles using [brew](https://formulae.brew.sh/formula/make) or [manually](https://www.gnu.org/software/make/#download) 

## Project strucure

This Go-based backend project is organized into several directories and files, each serving a distinct purpose in the implementation and management of the application.

```
backend
├── Makefile
├── README.md
├── build
│   └── Dockerfile
├── cmd
│   └── server
│       └── main.go         # The entry point of the application, where the server is initialized and started.
├── config.go               # Contains server configuration settings, such as environment variables or other settings required by the server. 
├── ctx
│   └── user.go
├── docker-compose.yml
├── docs
│   ├── openapi.yaml       # The OpenAPI specification file used to generate type-safe server code with oapi-codegen. 
│   └── spec.go
├── go.mod
├── go.sum
├── http                   # The package containing all the HTTP-related code.
│   ├── errorhandler
│   │   ├── request.go
│   │   └── response.go
│   ├── health.go
│   ├── middleware
│   │   ├── auth.go
│   │   └── validation.go
│   ├── server.go          # The central HTTP server setup file, managing routes and server configuration.
│   └── v1                 # The implementation of the API according to the version 1 specification. 
│       ├── api.gen.go     # Auto-generated code for the API from openapi.yaml using oapi-codegen.
│       ├── api.go         # Implementation of the API endpoints generated in api.gen.go 
│       ├── items.go       # Business logic related to managing items. 
│       └── items_test.go
├── postgresql             # Contains the code for interacting with the PostgreSQL database.
│   ├── db.gen.go          # Auto-generated database interfaces based on the SQL schema with sqlc
│   ├── db.go
│   ├── items.commands.sql.gen.go       # Auto-generated SQL commands for inserting, updating, or deleting data from the sql commands in (/postgresql/.schema)
│   ├── items.queries.sql.gen.go        # Auto-generated SQL queries for selecting data from the database from the sql queries in (/postgresql/.schema)
│   ├── migrations.go      # Handles database schema migrations from the sql schema in (/postgresql/.schema)
│   ├── models.gen.go      # Auto-generated database models from the sql statements in (/postgresql/.schema) with sqlc
│   ├── querier.gen.go     # Auto-generated code for executing queries from the sql statements in (/postgresql/.schema) with sqlc
│   └── sqlc.yaml
└── tools
    └── tools.go
```

This project structure follows a modular approach, where different parts of the application (HTTP, database, API specification) are kept in separate directories to maintain clarity and manageability. The usage of code generation tools like oapi-codegen and sqlc ensures that the code remains type-safe and maintainable as the project grows.

### Code generation

This code generation approach allows you to focus on writing the logic that matters to your application while the generated code takes care of the repetitive and boilerplate tasks.

In Go projects, the go generate command is commonly used to automate code generation tasks, such as generating types from specifications, creating mock objects, or creating database query methods from SQL schemas. This command is executed within the Go project and reads special //go:generate comments embedded in source code files to run specific code generation tools. These tools produce the corresponding Go code, which is then used in the project.


The //go:generate directive is a special comment in Go files that specifies which external commands or tools should be executed when go generate is run. These comments are typically placed just before the code that requires code generation.

For example, in this project you see this comments in [api.go](./http/v1/api.go) and [db.go](./postgresql/db.go):

`go generate ./...` looks for all files in the project that contain the //go:generate directive and runs the specified commands. It is typically run as part of the development workflow.

Once the go generate command is executed, the generated files are created and stored in the project directory. These files typically follow a naming convention, such as ending with .gen.go, to clearly indicate that they are automatically generated and should not be edited manually.

These generated files should be committed to the project's Git repository so that they are part of the codebase and changes can be tracked with git. Since the generated code is committed to the repository, it should be treated as a source of truth and should not be modified manually. Instead, any necessary changes or updates should be made to the configuration files (e.g., the OpenAPI spec or SQL schema) and then regenerated by running go generate again.

### local development

