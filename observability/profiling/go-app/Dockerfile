FROM golang:1.26-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags="-s -w" \
    -o profiling-demo .

FROM alpine:3.22

RUN adduser -D -u 10001 appuser

WORKDIR /app

COPY --from=builder /app/profiling-demo .

USER 10001

EXPOSE 8080

ENTRYPOINT ["/app/profiling-demo"]

