# HUST 有线校园网自动重连

把 OpenWrt 路由器的 WAN 口接到华中科技大学校园网后，本项目会自动探测 ePortal 认证页、登录，并在断网后持续重试。适合宿舍路由器、软路由和其他需要无人值守运行的 Linux 设备。

> 本项目不是学校官方软件。认证协议或校园网策略变化后可能需要调整；请遵守学校网络使用规定，不要共享账号或绕过并发设备限制。

## 这个版本解决了什么

- 不再只依赖单个网站，依次使用多个纯 HTTP 连通性入口发现认证页。
- 同时识别 `Location` 重定向和网页脚本中的 ePortal 地址。
- 在线时每 15 秒检查一次；掉线或认证失败时快速重试。
- 提供 OpenWrt `procd` 开机自启和进程拉起脚本。
- 日志不输出密码、MAC 地址或完整认证参数。
- 账号配置独立存放，示例配置和 `.gitignore` 可避免误提交凭据。

## 适用范围

已知目标是 HUST 使用的 ePortal 认证流程。典型拓扑如下：

```text
校园网墙口 ── 网线 ── OpenWrt WAN 口 ── 你的设备
```

如果 WAN 口拿不到 IPv4 地址，问题通常发生在 DHCP、墙口开通状态或其他前置认证环节，本程序无法替代这些步骤。

## 快速安装到 OpenWrt

### 1. 选择可执行文件

从 [Releases](https://github.com/APinkCube/hust-wired-auto-reconnect/releases) 下载与路由器 CPU 对应的压缩包。可先在路由器上查看架构：

```sh
uname -m
opkg print-architecture
```

常见对应关系：

| 路由器输出 | Release 目标 |
| --- | --- |
| `x86_64` | `x86_64-unknown-linux-musl` |
| `aarch64` | `aarch64-unknown-linux-musl` |
| `armv7l` | `armv7-unknown-linux-musleabihf` |
| `mips` | `mips-unknown-linux-musl` |
| `mipsel` | `mipsel-unknown-linux-musl` |

拿不准时，不要强行运行；在 Issue 中附上以上两条命令的输出即可。

### 2. 上传并安装

在电脑上解压可执行文件，然后连同安装脚本上传到路由器：

```sh
scp hust-network-login openwrt/hust-login.init openwrt/install.sh root@192.168.1.1:/tmp/
ssh root@192.168.1.1
sh /tmp/install.sh /tmp/hust-network-login /tmp/hust-login.init
```

安装脚本会在终端中询问学号和校园网密码。密码输入不会回显，并写入权限为 `600` 的 `/etc/hust-network-login.conf`。凭据不会写入命令行参数或本仓库。

### 3. 检查运行状态

```sh
/etc/init.d/hust-login status
logread -e hust-network-login
```

常用管理命令：

```sh
/etc/init.d/hust-login restart
/etc/init.d/hust-login stop
/etc/init.d/hust-login disable
```

## 手动运行

配置文件只有两行：第一行是学号，第二行是校园网密码。请从示例复制，不要把真实配置提交到 Git：

```sh
cp openwrt/hust-network-login.conf.example my.conf
chmod 600 my.conf
./hust-network-login ./my.conf
```

也可以使用环境变量：

```sh
HUST_NETWORK_LOGIN_USERNAME='你的学号' \
HUST_NETWORK_LOGIN_PASSWORD='你的密码' \
./hust-network-login
```

只执行一次探测/认证并用退出码表示结果：

```sh
HUST_NETWORK_LOGIN_ONCE=1 ./hust-network-login ./my.conf
```

## 从源码编译

本机平台：

```sh
cargo build --release
cargo test
```

交叉编译建议使用 [cross](https://github.com/cross-rs/cross)：

```sh
cargo install cross
cross build --release --target aarch64-unknown-linux-musl
```

产物位于 `target/<目标架构>/release/hust-network-login`。

## 排查思路

- `No such file or directory` 但文件确实存在：通常是下载了错误架构或动态链接产物。
- 一直显示 `discovery failed`：先确认 WAN 口已获取校园网 IPv4 和默认路由。
- 显示 `portal login was rejected`：核对账号、密码和学校账号状态。
- 已在线但程序反复认证：校园网可能拦截了全部探测入口，请提交脱敏日志和认证页特征。
- 修改凭据：编辑 `/etc/hust-network-login.conf` 后执行 `/etc/init.d/hust-login restart`。

报告问题前请删除日志中的学号、IP、MAC、Cookie 和认证参数。

## 项目来源与许可证

本项目基于 [black-binary/hust-network-login](https://github.com/black-binary/hust-network-login) 修改，保留完整上游提交历史和原作者版权声明，并继续采用 [MIT License](LICENSE)。感谢原作者和历次贡献者。

本仓库新增内容主要来自一次真实的宿舍有线网/OpenWrt 部署整理，目的是给后续同学提供可复用、可审查的参考实现。
