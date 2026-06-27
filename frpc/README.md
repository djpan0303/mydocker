# frpc - frp 客户端容器

## 概述

本项目构建一个极简 frp 客户端（frpc）Docker 镜像（基于 `scratch` + busybox），用于将内网服务暴露到 frps 公网服务器。

## 镜像结构

```
frpc/
├── Dockerfile          # 镜像构建定义
├── frpc                # frp 客户端二进制文件
├── frpc.toml           # 容器内默认配置（含占位符，需实际部署时覆盖）
├── start_frpc.sh       # 容器启动脚本
├── rootfs/             # busybox rootfs（提供 shell 和基本工具）
├── tag_id.txt          # 镜像版本标签
├── conf/
│   └── frpc.toml       # 部署模板（含注释和示例，ctrl_container.sh 自动复制到 /data/conf/）
└── README.md           # 本文件
```

## 配置说明

### 基础连接配置

| 字段 | 说明 | 示例 |
|------|------|------|
| `serverAddr` | frps 服务端地址 | `"us.tinybear.cc"` |
| `serverPort` | frps 服务端端口 | `5443`（需与 frps 的 `bindPort` 一致） |
| `user` | **客户端唯一标识**，在多台机器共享同一 frps 时必须为每台设置不同值 | `"tx-pc"`, `"vm-192-168-1-6"` |

### 认证配置

| 字段 | 说明 |
|------|------|
| `auth.method` | 认证方式，支持 `token` 或 `oidc` |
| `auth.token` | 认证令牌，需与 frps 服务端配置一致 |

### 日志配置

| 字段 | 说明 | 可选值 |
|------|------|--------|
| `log.to` | 日志输出目标 | `"console"` 或文件路径 |
| `log.level` | 日志级别 | `trace`, `debug`, `info`, `warn`, `error` |

### 代理配置 `[[proxies]]`

每个 `[[proxies]]` 块定义一个代理隧道，可配置多个。`name` 必须在同一客户端内唯一。

| 字段 | 说明 |
|------|------|
| `name` | 代理名称，需唯一 |
| `type` | 协议类型：`tcp`, `udp`, `http`, `https`, `stcp`, `xtcp` |
| `localIP` | 本地服务的 IP 地址 |
| `localPort` | 本地服务的端口 |
| `remotePort` | 在 frps 上暴露的端口（tcp/udp 类型使用） |
| `customDomains` | HTTP/HTTPS 虚拟主机域名（http/https 类型使用） |
| `secretKey` | 加密密钥（stcp/xtcp 类型使用） |

### 完整配置示例

```toml
serverAddr = "us.tinybear.cc"
serverPort = 5443

user = "my-machine"

auth.method = "token"
auth.token = "your-token-here"

log.to = "console"
log.level = "info"

# 暴露本机 SSH
[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 60222

# 暴露本机 Web 服务
[[proxies]]
name = "web"
type = "http"
localIP = "127.0.0.1"
localPort = 8080
customDomains = ["web.example.com"]
```

## 使用方法

### 启动容器

```bash
./ctrl_container.sh --start frpc
```

该命令会：
1. 停止已有的 frpc 容器
2. 拉取最新镜像
3. 若 `/data/conf/frpc.toml` 不存在，自动从 `frpc/conf/frpc.toml` 复制
4. 以 `--network host` 模式启动容器（使用宿主机网络）

### 配置文件位置

容器启动后，实际使用的配置在 `/data/conf/frpc.toml`。**修改配置后需重启容器生效**：

```bash
./ctrl_container.sh --restart frpc
```

### 多机器部署

每台机器部署 frpc 时，**必须修改 `user` 字段为唯一值**，否则 frps Dashboard 中只会显示一个客户端：

| 机器 | user 值 |
|------|---------|
| 本机 | `"tx-pc"` |
| 虚拟机 192.168.1.6 | `"vm-192-168-1-6"` |

### 验证连接

访问 frps Dashboard：`http://<serverAddr>:6443`，应能看到对应 `user` 名称的客户端及其代理列表。

## 构建镜像

```bash
# 构建
docker build -t us.tinybear.cc:5000/frpc:<version> .

# 推送
docker push us.tinybear.cc:5000/frpc:<version>

# 更新 tag_id.txt 以指定默认版本
echo "<version>" > tag_id.txt
```
