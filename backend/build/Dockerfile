FROM docker.io/golang:1.23-alpine as BUILDER

ENV GOMODCACHE=/go/pkg/mod

RUN apk add --no-cache ca-certificates

WORKDIR /app
COPY go.mod .
COPY go.sum .

RUN go mod download

COPY . .

ARG GOOS=linux
ARG GOARCH=amd64
ARG CGO_ENABLED=0

RUN go build -o /go/bin/app ./cmd/server

FROM  docker.io/golang:1.23-alpine AS DEV

ENV GOMODCACHE=/go/pkg/mod
ENV GOOS=linux
ENV CGO_ENABLED=0

WORKDIR /app

RUN apk add --no-cache make && go install github.com/air-verse/air@latest

# Copy Go modules cache from BUILDER
COPY --from=BUILDER --chmod=777 /go/pkg/mod /go/pkg/mod
COPY --from=BUILDER --chmod=777 /root/.cache/go-build /root/.cache/go-build

COPY --from=BUILDER /app .

CMD ["make", "dev/live"]

FROM scratch

COPY --from=BUILDER --chmod=775 /go/bin/app /go/bin/app
COPY --from=BUILDER /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
EXPOSE 8080

ENTRYPOINT ["/go/bin/app"]