# backend/Dockerfile

# ---- Build Stage ----
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy dependency files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -o main ./cmd/api

# ---- Run Stage ----
FROM alpine:latest

WORKDIR /app

# Install ca-certificates untuk HTTPS calls
RUN apk --no-cache add ca-certificates

# Copy binary dari build stage
COPY --from=builder /app/main .

# Buat folder uploads
RUN mkdir -p uploads

EXPOSE 8080

CMD ["./main"]