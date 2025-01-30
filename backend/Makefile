# Change these variables as necessary.
main_package_path = ./cmd/server
binary_name = app

.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'


# ==================================================================================== #
# QUALITY CONTROL
# ==================================================================================== #

## audit: run quality control checks
.PHONY: audit
audit: test
	go mod tidy -diff
	go mod verify
	test -z "$(shell gofmt -l .)"
	go vet ./...
	go run honnef.co/go/tools/cmd/staticcheck@latest -f=stylish ./...
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...


## test: run all tests
.PHONY: test
test:
	go test -v -race ./...


# ==================================================================================== #
# DEVELOPMENT
# ==================================================================================== #

## tidy: tidy modfiles and format .go files
.PHONY: tidy
tidy:
	go mod tidy -v
	go fmt ./...

## build: run go generate to regenerate all files for all //go:generate commands within the project (https://go.dev/blog/generate)
.PHONY: generate
generate:
	go generate ./...

## build: build the application
.PHONY: build
build:
	go build -o=/tmp/bin/${binary_name} ${main_package_path}

## run: run the application
.PHONY: run
run: build
	/tmp/bin/${binary_name}

## run/live: run the application with reloading on file changes
.PHONY: dev/live
dev/live:
	go run github.com/air-verse/air@latest \
		-d \
		--build.cmd "make build" \
		--build.bin "/tmp/bin/${binary_name}" \
		--build.delay "100" \
		--build.kill_delay "100" \
		--build.poll "true" \
		--build.exclude_dir "tmp" \
		--build.include_ext "go,sql,yaml" \
		--misc.clean_on_exit "true"
