# Build Caddy
docker build -t grayblock/searxng-caddy:latest -f Dockerfile.caddy .
docker push grayblock/searxng-caddy:latest

# Build SearXNG
docker build -t grayblock/searxng-custom:latest -f Dockerfile.searxng .
docker push grayblock/searxng-custom:latest