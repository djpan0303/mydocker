FROM ubuntu:22.04

RUN mkdir -p /data/log

# ENV HTTP_PROXY=http://127.0.0.1:8118 \
#     HTTPS_PROXY=http://127.0.0.1:8118 \
#     http_proxy=http://127.0.0.1:8118 \
#     https_proxy=http://127.0.0.1:8118

RUN apt update && apt install curl -y \
        && apt install vim -y \
        && apt install systemctl -y \
        && apt install python2.7 -y \
        && apt install privoxy -y \
        && apt -y install curl \
        && apt -y install net-tools \
        && echo "forward-socks5t   /               127.0.0.1:1080 ." >> /etc/privoxy/config \
        && sed -i "s/listen-address  127.0.0.1:8118/listen-address  0.0.0.0:8118/g" /etc/privoxy/config \
        && systemctl enable privoxy

COPY app /data/app



ENTRYPOINT [ "/data/app/start_service.sh" ]
CMD [ "ssr" ]
