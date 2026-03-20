FROM golang:1.22-alpine AS builder

WORKDIR /src

COPY go.mod .
COPY main.go .

RUN go build -o /bin/cart-service .

FROM alpine:3.20

WORKDIR /app

COPY --from=builder /bin/cart-service /usr/local/bin/cart-service

EXPOSE 8080

CMD ["cart-service"]
