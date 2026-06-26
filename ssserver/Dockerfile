# Stage 1: download ShadowsocksR source
FROM alpine:3.18 AS builder
RUN wget -q https://github.com/shadowsocksrr/shadowsocksr/archive/3.2.2.tar.gz && \
    tar zxf 3.2.2.tar.gz

# Stage 2: runtime
FROM alpine:3.18

# Install Python 3 and OpenSSL (for libcrypto)
RUN apk add --no-cache \
        python3 \
        openssl && \
    ln -sf /usr/bin/python3 /usr/bin/python

# Copy ShadowsocksR server from builder
COPY --from=builder /shadowsocksr-3.2.2/shadowsocks /usr/local/shadowsocks

# Fix Python 3.11 compatibility (collections.MutableMapping removed)
RUN sed -i 's/collections\.MutableMapping/collections.abc.MutableMapping/g' \
    /usr/local/shadowsocks/lru_cache.py

# Create config directory (config.json will be mounted at runtime)
RUN mkdir -p /data/conf

EXPOSE 9544

CMD ["python", "/usr/local/shadowsocks/server.py", "-c", "/data/conf/config.json"]
