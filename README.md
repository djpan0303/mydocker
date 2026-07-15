# Docker Setup

开始前务必保证两件事：
+ 设置好域名解析，将registry.tinybear.cc解析到registry server所在的服务器IP
+ 不论是推送构建好的镜像还是拉取镜像，需要设置号/etc/docker/daemon.json,在其中加入如下配置：
```
{
  "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"],
  "insecure-registries": ["registry.tinybear.cc:5000"]
}
```

搭建registry时docker pull拉取官方镜像可能会拉取失败，需要设置docker代理。
sudo mkdir -p /etc/systemd/system/docker.service.d
vim /etc/systemd/system/docker.service.d/http-proxy.conf
添加如下内容：
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:8118"
Environment="HTTPS_PROXY=http://127.0.0.1:8118"
Environment="NO_PROXY=localhost,127.0.0.1"

然后执行如下命令：
sudo systemctl daemon-reload
sudo systemctl restart docker

用如下命令检查代理是否设置正确：
sudo systemctl show --property=Environment docker

[如何优雅的给 Docker 配置网络代理](https://www.cnblogs.com/Chary/p/18096678)

# Registry Server

deploy and start registry server
```
registry_ctrl --start_server
```
启动服务器后，浏览器上打开tinybear.cc:8080可以看到当前仓库中的镜像。

stop registry server
```
registry_ctrl --stop_server
```


# Image
新增image，需要在container_ctrl.sh的start函数匹配对应的docker启动
build image without removing old image of current date
```
image_ctrl.sh --build ssclient
```

build image and remove old image of current date
```
image_ctrl.sh --cbuild ssclient
```

push image to registry server
```
image_ctrl.sh --push ssclient
```

# Container
容器总控脚本 `ctrl_container.sh` 只负责服务启停调度；`ssclient` 的业务细节（配置准备、8118 健康检测、监控进程管理）已拆分到 `ssclient/ctrl_ssclient.sh`。

start local container
```
container_ctrl.sh --start ssclient
```

stop local container
```
container_ctrl.sh --stop ssclient
```

log in local container
```
container_ctrl.sh --login ssclient
```

test local proxy health
```
container_ctrl.sh --test
```

## Proxy Monitor

`monitor_proxy.sh` 用于定时检测本机 `127.0.0.1:8118` 代理是否还能正常转发流量；如果连续失败达到阈值，会自动重启 `ssclient` 容器，然后再次复检。

推荐方式：将监控脚本作为 `ssclient` 生命周期的一部分，由 `ctrl_container.sh` 自动管理。
- `./ctrl_container.sh --start ssclient` 时自动后台启动监控
- `./ctrl_container.sh --stop ssclient` / `--restart ssclient` 时自动停止旧监控
- 如果 `ssclient` 容器不在运行，`monitor_proxy.sh` 会自动退出

因此不建议把监控脚本单独做“固定开机常驻”，否则可能在容器没启动时空跑。

脚本会先做“直连探测”（默认 `https://www.baidu.com`），用于区分两种情况：
- 直连失败：说明本机外网本身异常，跳过代理检测与重启（避免无意义重启）
- 直连成功但代理失败：说明代理链路异常，按阈值执行自动重启

默认检测内容：
- HTTP 204 探测
- HTTPS 204 探测
- 查询代理出口 IP

单次执行：
```
./monitor_proxy.sh
```

连续监控：
```
./monitor_proxy.sh --watch --interval 60 --max-failures 3
```

指定直连探测地址：
```
./monitor_proxy.sh --direct-probe-url https://www.baidu.com
```

如果想交给 cron 每分钟执行一次，可加日志：
```
* * * * * /home/ubt/mydocker/monitor_proxy.sh --max-failures 3 --log-file /var/log/proxy-monitor.log
```

常用参数：
- `--image ssclient`：指定要重启的容器名
- `--max-failures 3`：连续失败多少次后重启
- `--interval 60`：`--watch` 模式下的轮询间隔
- `--direct-probe-url <url>`：直连探测地址，默认 `https://www.baidu.com`
- `--log-file <path>`：把日志追加写入文件

# frps (FRP Server)

## Build & Push

build image and push to registry
```
cd frps && docker build -t registry.tinybear.cc:5000/frps:0.58.1 -t registry.tinybear.cc:5000/frps:latest . && docker push registry.tinybear.cc:5000/frps:0.58.1 && docker push registry.tinybear.cc:5000/frps:latest
```

## Deploy

The image uses `FROM scratch` with busybox, total size ~24MB.
On startup, the script checks `/data/conf/frps.toml`:
- If not exists, copies default config
- If `webServer.password` or `auth.token` is empty, auto-generates 16-char random credentials

first time pull and run
```
docker pull registry.tinybear.cc:5000/frps:0.58.1
docker run -d --name frps --restart=always --network host \
  -v /data/conf:/data/conf \
  registry.tinybear.cc:5000/frps:0.58.1
```

## Management

```
docker logs frps           # view container logs
docker restart frps        # restart container
docker stop frps           # stop container
docker rm -f frps          # force remove container
```

```
cat /data/conf/frps.toml   # view config (includes auto-generated credentials)
```

# frpc (FRP Client)

## Build & Push

```
cd frpc && docker build -t registry.tinybear.cc:5000/frpc:0.58.1 -t registry.tinybear.cc:5000/frpc:latest . && docker push registry.tinybear.cc:5000/frpc:0.58.1 && docker push registry.tinybear.cc:5000/frpc:latest
```

## Deploy

On startup, the script checks `/data/conf/frpc.toml` and copies the default config if not exists. Edit the config to set `serverAddr`, `auth.token`, and `proxies` before use.

```
docker pull registry.tinybear.cc:5000/frpc:0.58.1
docker run -d --name frpc --restart=always --network host \
  -v /data/conf:/data/conf \
  registry.tinybear.cc:5000/frpc:0.58.1
```

## Management

```
docker logs frpc            # view container logs
docker restart frpc         # restart container
docker stop frpc            # stop container
docker rm -f frpc           # force remove container
```

```
cat /data/conf/frpc.toml    # view/edit config (serverAddr, auth.token, proxies)
```

## Rustdesk

自建 RustDesk 远程控制服务，包含 hbbs (ID/Rendezvous 服务器) 和 hbbr (中继/Relay 服务器)。

### Build & Push

```
./image_ctrl.sh --cbuild rustdesk
./image_ctrl.sh --push rustdesk
```

### Deploy

镜像基于 `debian:bookworm-slim`，启动脚本首次运行自动生成 ed25519 密钥对，持久化到 `/data/conf/`。

```
docker pull us.tinybear.cc:5000/rustdesk:20260630
docker run -d --name rustdesk --restart=always --network host \
  -e RELAY_ADDR=us.tinybear.cc \
  -v /data/conf:/data/conf \
  us.tinybear.cc:5000/rustdesk:20260630
```

### 端口

| 端口  | 协议    | 服务 | 用途                               |
| ----- | ------- | ---- | ---------------------------------- |
| 21115 | TCP     | hbbs | NAT 类型检测                       |
| 21116 | TCP+UDP | hbbs | ID 注册/心跳 + TCP 打洞            |
| 21117 | TCP     | hbbr | 中继连接                           |
| 21118 | TCP     | hbbs | WebSocket (Web 控制台, 仅 WS 协议) |
| 21119 | TCP     | hbbr | WebSocket (Web 控制台, 仅 WS 协议) |

### 客户端配置

RustDesk 客户端 → 设置 → 网络 → ID/中继服务器：

| 字段       | 值                                              |
| ---------- | ----------------------------------------------- |
| ID 服务器  | `us.tinybear.cc`                                |
| 中继服务器 | `us.tinybear.cc`                                |
| Key        | 查看 `/data/conf/id_ed25519.pub` 或容器启动日志 |

端口使用默认值即可（ID: 21116, 中继: 21117），无需在地址中加端口号。

### 密钥

- 密钥文件保存在 `/data/conf/id_ed25519` 和 `id_ed25519.pub`
- 首次启动自动生成，后续重启复用
- 客户端必须填入匹配的公钥才能连接

```
cat /data/conf/id_ed25519.pub   # 查看公钥
docker logs rustdesk 2>&1 | grep "Key:"   # 从日志查看
```

### 管理

```
docker logs rustdesk            # 查看日志
docker restart rustdesk         # 重启
docker exec -it rustdesk bash   # 进入容器
```

## RustDesk GFW 隧道脚本

`setup-rustdesk-tunnel.sh` 用于在**国内受 GFW 干扰的电脑**上一键配置 RustDesk 隧道。GFW 会 RST 阻断 TCP 21115/21116 端口，导致 RustDesk 客户端无法连接 ID 服务器。脚本通过 SSH 隧道加密 TCP 流量 + iptables 透明重定向来绕过封锁（UDP 直连不受影响）。

### 原理

```
RustDesk 客户端 → 199.180.117.155:21116
       ↓ iptables DNAT 重定向
127.0.0.1:21116 → SSH 隧道(加密) → VPS:21116 → hbbs
```

脚本会自动完成：
1. 配置 SSH 免密登录到 `us.tinybear.cc`
2. 创建 SSH 隧道 systemd 用户服务（开机自启，端口 21115/21116/21117）
3. 配置 iptables 透明重定向规则
4. 持久化 iptables 规则（开机自动恢复）
5. 更新 RustDesk 客户端配置文件

### 用法

```bash
bash setup-rustdesk-tunnel.sh <sudo密码>
```

示例：
```bash
bash setup-rustdesk-tunnel.sh mypassword
```

查看帮助：
```bash
bash setup-rustdesk-tunnel.sh --help
```

不带参数运行会提示正确用法：
```bash
bash setup-rustdesk-tunnel.sh
# 错误: 缺少 sudo 密码参数
# 用法: bash setup-rustdesk-tunnel.sh <sudo密码>
```

### 前提

- 目标机器需要安装 `ssh`、`iptables`、`nc`、`systemd`
- 目标机器需要 sudo 权限（用于配置 iptables 和 systemd linger）
- 需要能 SSH 连接到 `us.tinybear.cc`（首次运行会自动配置 ssh-copy-id）

### 验证

脚本执行后会自动验证 TCP 21115/21116 和 UDP 21116 的连通性。也可手动验证：

```bash
# 检查隧道服务状态
systemctl --user status rustdesk-tunnel.service

# 检查隧道端口监听
ss -tlnp | grep -E "2111[5-7]"

# 检查 iptables 规则
sudo iptables -t nat -L OUTPUT -n | grep 2111
```