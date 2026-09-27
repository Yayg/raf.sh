FROM debian:bookworm-slim AS build
ARG HUGO_VERSION=0.139.4
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && curl -sL -o /tmp/hugo.tar.gz \
       "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" \
    && tar -xzf /tmp/hugo.tar.gz -C /usr/local/bin hugo \
    && chmod +x /usr/local/bin/hugo \
    && rm /tmp/hugo.tar.gz \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY . .
RUN hugo --minify

FROM nginx:alpine
COPY --from=build /src/public /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
