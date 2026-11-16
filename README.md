# sing-box for FreeBSD x86-64（TUN）

为 **FreeBSD / amd64（x86-64，`GOAMD64=v1`）** 构建 sing-box，支持 `system`、`gvisor` 和 `mixed` 三种 TUN 栈。

本仓库跟踪上游最新正式版本，自动构建并在虚拟机中测试，通过后发布至 [Releases](https://github.com/Opnwall/Freebsd-box/releases)。仅固定目标平台，不裁剪常用代理协议；具体编译标签见 [`build.env`](build.env)。

## 下载与使用

从 [Releases](https://github.com/Opnwall/Freebsd-box/releases) 下载构建产物：

| 文件 | 说明 |
| --- | --- |
| `bsd-box-freebsd-amd64.xz` | sing-box 可执行文件的压缩包，沿用原文件名以保持兼容 |
| `SHA256SUMS` | 压缩包的 SHA-256 校验值 |
| `build-info.txt` | 源码、依赖、Go 版本和编译参数 |

解压并检查版本、配置：

```sh
xz -dk bsd-box-freebsd-amd64.xz
chmod +x bsd-box-freebsd-amd64
./bsd-box-freebsd-amd64 version
./bsd-box-freebsd-amd64 check -c config.json
```

## TUN 配置

配置示例见 [`template.json`](template.json)。在 FreeBSD 上使用 TUN 时：

- 以 root 身份运行，并确保 `if_tun` 可用。
- 默认模板使用 `auto_route: false`。建议先验证 TUN，再按实际网络配置路由、DNS 和防火墙放行规则。
- pfSense / OPNsense 的防火墙规则和 DNS 需自行配置。
- 上游不支持 FreeBSD 的 `route.auto_detect_interface` 和 `bind_interface`，请勿启用这些字段。

### 自动路由

`auto_route: true` 沿用原补丁的独立 FIB 方案，`fib_index` 默认为 `2022`。启用前，需要确保 `net.fibs` 足以容纳所用索引，并设置 `net.add_addr_allfibs=1`。请按程序提示修改 `/boot/loader.conf`，重启后生效。

> 自动化测试覆盖 `auto_route: false` 下的启动、手工路由转发和退出清理。真实网关中的自动路由、pfSense / OPNsense 防火墙配置及转发吞吐仍需在实际设备上验证。

## 自动构建

| 触发方式 | 行为 |
| --- | --- |
| 每小时定时检查 | 检查上游最新正式 Release，跳过预发布版和已发布版本；发现新版本后构建、测试并发布 |
| 主分支 `master` 更新 | 自动构建，测试通过后发布 |
| 其他分支及 Pull Request | 构建产物仅上传至 Actions artifact |
| Actions 手动运行 | 支持手动触发工作流 |

新版本的补丁、编译或测试未通过时，不发布产物，下次定时检查自动重试。

## 发布前测试

发布前，`system`、`gvisor`、`mixed` 三种 TUN 栈均需在 FreeBSD 14.3 amd64 虚拟机中通过启动、实际流量转发和退出清理测试。

### 测试环境

FreeBSD VNET jail 中运行独立的 TCP / UDP 回显服务。测试客户端通过 FIB 1 中的主机路由强制将流量送入 `tun9`，代理通过 FIB 0 经 `epair` 连接服务端。整个测试不依赖公共网站。

### 检查项目

每种 TUN 栈执行相同的检查：

- **数据完整性**：覆盖 IPv4 / IPv6，测试 TCP 256 KiB 往返及 UDP 64、1200、4096 字节往返，对随机载荷逐字节校验。
- **防止绕过 TUN**：暂停代理后，相同路由下的 TCP / UDP 请求必须失败。
- **路由与抓包**：确认路由指向 `tun9`，并在 TUN 抓包中验证两种地址族、两种协议的请求和响应。
- **退出清理**：确认代理退出后 TUN 设备已清理。

任何一项失败，均阻止发布和保存迁移补丁。Actions 的 `tun-network-tests` artifact 保存 JSON 校验结果、服务日志、路由记录和 pcap，供排查使用。

## 本地编译

Linux 和 macOS 均可交叉编译。需要 Bash、Go、curl、jq、patch、tar 和 xz；Go 版本见 [`.go-version`](.go-version)。

```sh
scripts/prepare.sh
scripts/build.sh
```

本地默认构建版本见 [`build.env`](build.env)，Actions 使用上游最新正式版本。重新准备源码前，请先删除生成目录 `.build/`。

`prepare.sh` 从 sing-box 的 `go.mod` 获取准确的 `sing-tun` 依赖版本，通过 Go 模块下载处理伪版本，再应用主分支中的补丁。构建不依赖 `hidden` 分支或浮动的 `sing-tun stable` 分支。

## 自动迁移

补丁无法直接应用时，工作流使用 `patches/bases/` 中记录的原始源码进行三方合并，保留不冲突的上游修改。迁移不使用 API，也不猜测接口或逻辑变化。

迁移遵循以下规则：

1. 每次仅尝试一次，不降低测试要求。
2. 候选补丁必须重新编译，并通过三种 TUN 栈的启动、流量转发和清理测试，才会保存到主分支并发布。
3. 出现合并冲突、编译失败或测试失败时停止发布，等待下次定时检查重试。
4. 修改补丁时，必须同步更新对应基线和校验值；基线不匹配时停止迁移。
5. 测试通过前，候选补丁仅保存在本次 Actions artifact 中。

## 补丁来源

FreeBSD TUN 补丁改编自 [Vincent-Loeng/bsd-box 的 hidden 分支](https://github.com/Vincent-Loeng/bsd-box/tree/hidden)，保留 FreeBSD TUN 代码的 WireGuard / MIT 版权说明，并适配当前依赖和 gVisor 报文头。

本版本仅包含 FreeBSD TUN 补丁，未增加原仓库的进程匹配、redirect 或订阅扩展。
