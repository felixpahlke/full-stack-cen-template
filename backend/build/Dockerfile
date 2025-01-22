FROM docker.io/golang:1.23-alpine as BUILDER

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

FROM scratch

COPY --from=BUILDER --chmod=775 /go/bin/app /go/bin/app
COPY --from=BUILDER /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
EXPOSE 8080

ENTRYPOINT ["/go/bin/app"]