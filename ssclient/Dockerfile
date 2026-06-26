# Stage 1: builder - collect all runtime dependencies
FROM debian:buster-slim AS builder

# Use Debian archive (buster is EOL) with apt proxy for speed in China
RUN echo 'deb http://archive.debian.org/debian buster main' > /etc/apt/sources.list && \
    echo 'deb http://archive.debian.org/debian buster-backports main' >> /etc/apt/sources.list && \
    apt update && apt install -y --no-install-recommends \
    python2.7 \
    python2.7-minimal \
    libpython2.7-stdlib \
    libpython2.7-minimal \
    privoxy \
    ca-certificates \
    libsodium23 \
    libpcre3 \
    libffi6 \
    && rm -rf /var/lib/apt/lists/* /etc/apt/apt.conf.d/99proxy

# Collect all required files into /rootfs
RUN mkdir -p /rootfs && \
    # --- python2.7 ---
    mkdir -p /rootfs/usr/bin && \
    cp /usr/bin/python2.7 /rootfs/usr/bin/ && \
    # --- python stdlib ---
    mkdir -p /rootfs/usr/lib && \
    cp -a /usr/lib/python2.7 /rootfs/usr/lib/ && \
    # --- privoxy ---
    mkdir -p /rootfs/usr/sbin && \
    cp /usr/sbin/privoxy /rootfs/usr/sbin/ && \
    # --- privoxy config ---
    mkdir -p /rootfs/etc/privoxy && \
    cp -a /etc/privoxy/* /rootfs/etc/privoxy/ && \
    # --- CA certs ---
    mkdir -p /rootfs/etc/ssl/certs && \
    cp -a /etc/ssl/certs/* /rootfs/etc/ssl/certs/ && \
    # --- nsswitch.conf (required for DNS resolution) ---
    mkdir -p /rootfs/etc && \
    cp /etc/nsswitch.conf /rootfs/etc/ && \
    # --- passwd/group (required by python) ---
    cp /etc/passwd /rootfs/etc/ && \
    cp /etc/group /rootfs/etc/

# Collect shared libraries for python2.7, privoxy, and python .so modules
RUN mkdir -p /rootfs/lib /rootfs/lib/x86_64-linux-gnu /rootfs/usr/lib/x86_64-linux-gnu && \
    for bin in /usr/bin/python2.7 /usr/sbin/privoxy $(find /usr/lib/python2.7/lib-dynload -name '*.so' 2>/dev/null); do \
    ldd "$bin" 2>/dev/null | while read -r line; do \
    case "$line" in \
    *linux-vdso*|*ld-linux-x86-64*);; \
    *" => "*" ("*) \
    lib=$(echo "$line" | awk '{print $3}'); \
    [ -n "$lib" ] && [ -f "$lib" ] && cp -n "$lib" "/rootfs$(dirname "$lib")/" 2>/dev/null || true;; \
    esac; \
    done; \
    done && \
    # ld-linux (dynamic linker) — binaries expect it at /lib64/
    mkdir -p /rootfs/lib64 && \
    cp /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /rootfs/lib64/ && \
    # libsodium (used by shadowsocks via ctypes)
    cp /usr/lib/x86_64-linux-gnu/libsodium.so* /rootfs/usr/lib/x86_64-linux-gnu/ 2>/dev/null || true && \
    # Create unversioned symlinks for ctypes find_library (openssl, ffi)
    for lib in libcrypto libssl libffi; do \
    ver=$(ls /rootfs/usr/lib/x86_64-linux-gnu/${lib}.so.* 2>/dev/null | head -1); \
    [ -n "$ver" ] && ln -sf "$(basename "$ver")" "/rootfs/usr/lib/x86_64-linux-gnu/${lib}.so" 2>/dev/null || true; \
    done && \
    # Also link directly under /usr/lib for glob-based find_library fallback
    ln -sf x86_64-linux-gnu/libcrypto.so.1.1 /rootfs/usr/lib/libcrypto.so.1.1 && \
    ln -sf libcrypto.so.1.1 /rootfs/usr/lib/libcrypto.so && \
    ln -sf x86_64-linux-gnu/libssl.so.1.1 /rootfs/usr/lib/libssl.so.1.1 && \
    ln -sf libssl.so.1.1 /rootfs/usr/lib/libssl.so && \
    ln -sf x86_64-linux-gnu/libffi.so.6 /rootfs/usr/lib/libffi.so.6 && \
    ln -sf libffi.so.6 /rootfs/usr/lib/libffi.so

# Stage 2: minimal image
FROM scratch

# busybox rootfs (shell + basic tools)
COPY rootfs/ /

# python + privoxy + all deps from builder
COPY --from=builder /rootfs/ /

# app code and config
COPY app/ /data/app/
COPY conf/ /data/conf/

EXPOSE 8118

ENTRYPOINT ["/data/app/start_service.sh"]
