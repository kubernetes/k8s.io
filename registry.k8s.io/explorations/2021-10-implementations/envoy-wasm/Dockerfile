# Deploying in Kubernetes
# Create container image

FROM tinygo/tinygo:0.20.0 AS build
WORKDIR /app
COPY go.* *.go /app/
RUN tinygo build -o wasm.wasm -scheduler=none -target=wasi /app/main.go

FROM envoyproxy/envoy-distroless:v1.20.0 AS final
COPY --from=build /app/wasm.wasm /etc/envoy/wasm.wasm
