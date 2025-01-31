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

### Local Development Options

You can develop this project locally in three primary ways. All methods support setting environment variables manually or via a .env file.

1. Run Locally with IDE Debugging: Start the application with an IDE (such as GoLand or VS Code) and set breakpoints for debugging. Simply run the [main](./cmd/server/main.go) function.
2. Live Hot Reload with [air](https://github.com/air-verse/air). Use Air for automatic hot reloading during development. Start it with:
```shell
  make dev/live
```
3. Run the Full Dev Stack with Docker Compose. Use docker-compose.yml to spin up the entire development environment, including a PostgreSQL database and live hot reloading with [air](https://github.com/air-verse/air): 
```shell
  docker-compose up
```

### Makefile

This project includes a Makefile to streamline common development tasks such as building, testing, linting, and running the application. Below is an overview of the available commands:

##### 📌 Quality Control

- `make audit` – Runs quality control checks, including:
  - Running tests
  - Checking go.mod consistency
  - Formatting validation (gofmt)
  - Running go vet for static analysis
  - Running golangci-lint, staticcheck, and govulncheck for linting and security scanning

- `make test` – Runs all tests with the race detector enabled.

##### 🛠 Development Utilities
- `make tidy` – Tidies go.mod and formats .go files.
- `make generate` – Runs go generate to regenerate code from //go:generate directives.

##### 🚀 Building & Running
- `make build` – Builds the application binary and places it in /tmp/bin/app.
- `make run` – Builds and runs the application.
- `make dev/live` – Starts the application with Air for live hot reloading.

> 💡 Run `make help` to list all available commands with descriptions.

### Migrations

This project uses [mgx](https://github.com/z0ne-dev/mgx) for database migrations. mgx is a Go-native migration tool that enables defining and executing migrations directly in Go code instead of raw SQL files.

Migrations are automatically applied during application startup. mgx maintains a `__migrations` table to track executed migrations.

We manage our database schema and migrations in the postgresql/.schema/ folder, which is also used for SQL code generation with sqlc.

1. Adding a New Schema and Migration
2. Create a new schema under ./postgresql/.schema/v[n].
3. Add an execution entry to migrations.go.

Update your SQL statements and regenerate the database client code using:

```shell
  make generate
```

> Note: Always ensure your SQL statements are up to date before regenerating your database client.

### Tests

This project follows a pragmatic testing approach by focusing primarily on simple unit tests while leveraging test containers for integration tests when real dependencies are required.

##### Unit Testing Approach

- Write simple, focused unit tests to verify individual functions and components.
- Avoid unnecessary complexity in unit tests by keeping them isolated.
- Use mocks where real dependencies are not needed.

##### Using Test with Real Dependencies

When testing requires real dependencies, we can use Testcontainers for Go to spin up lightweight, disposable containers for services like databases.

[Testcontainers](https://testcontainers.com/guides/getting-started-with-testcontainers-for-go/) allows you to programmatically create and manage Docker containers for testing purposes. These containers ensure that tests run in a reproducible and isolated environment.

You can find a sample test using a postgresql database in [./http/v1/items_test.go](./http/v1/items_test.go)

##### Running Tests

Running all tests using:

`go test ./...` or `make test`

> For tests requiring external services, ensure Docker(with colima) or podman is running so that test containers can be provisioned automatically.

By following this approach, we ensure that tests are both fast and reliable while providing the flexibility to validate real-world scenarios when necessary.