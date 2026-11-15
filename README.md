# sing-box for FreeBSD x86-64 (TUN)

构建 **FreeBSD / amd64（x86-64，GOAMD64=v1）** 的 sing-box，支持 TUN 的 `system`、`gvisor`、`mixed` 栈。
## 构建与下载

每小时检查上游正式 Release；发现新版本后自动构建、测试并发布，已发布版本跳过。主分支 `master` 更新后也会自动编译，并在 FreeBSD 14.3 amd64 虚拟机检查三种 TUN 栈的启动和退出。检查成功后发布到本仓库 [Releases](https://github.com/Opnwall/Freebsd-box/releases)。也可从 Actions 手动运行。分支及 PR 构建仅上传 Actions artifact。

产物：

- `bsd-box-freebsd-amd64.xz`：兼容原文件名，解压后即 sing-box。
- `SHA256SUMS`：压缩文件的 SHA-256 校验值。
- `build-info.txt`：源码、依赖、Go 版本和编译参数。

Actions 自动使用上游最新正式版，跳过预发布版；Go 版本见 `.go-version`。本地默认版本见 `build.env`。新版本补丁或测试不通过时不会发布，下次检查自动重试。只固定目标平台，不裁剪常用代理协议；编译标签见 `build.env`。

```sh
xz -dk bsd-box-freebsd-amd64.xz
chmod +x bsd-box-freebsd-amd64
./bsd-box-freebsd-amd64 version
./bsd-box-freebsd-amd64 check -c config.json
```

## 本地交叉编译

需要 Bash、Go（版本见 `.go-version`）、curl、jq、patch、tar、xz。Linux 或 macOS 均可交叉编译：

```sh
scripts/prepare.sh
scripts/build.sh
```

重新准备源码前删除生成目录 `.build/`。`prepare.sh` 从 sing-box 的 `go.mod` 获取准确的 sing-tun 依赖，通过 Go 模块下载处理伪版本，然后应用主分支内的补丁；不依赖 `hidden` 分支或浮动的 sing-tun `stable` 分支。

## TUN 配置

见 [template.json](template.json)。在 FreeBSD 上以 root 运行，并确保 `if_tun` 可用。默认模板使用 `auto_route: false`，先验证 TUN，再按防火墙实际情况配置路由和 DNS。pfSense / OPNsense 的放行规则及 DNS 需自行配置。上游不支持 FreeBSD 的 `route.auto_detect_interface` 和 `bind_interface`，不要在配置中启用这些字段。

`auto_route: true` 沿用原补丁的独立 FIB 方案，`fib_index` 默认 2022，需要足够的 `net.fibs` 和 `net.add_addr_allfibs=1`；按程序提示配置 `/boot/loader.conf` 后重启。虚拟机启动检查覆盖 `auto_route: false`，不代表已验证真实网关上的自动路由或转发吞吐。

本版本仅包含 FreeBSD TUN 补丁，没有增加原仓库的进程匹配、redirect 或订阅扩展。补丁改编自 [Vincent-Loeng/bsd-box 的 hidden 分支](https://github.com/Vincent-Loeng/bsd-box/tree/hidden)，保留 FreeBSD TUN 代码的 WireGuard/MIT 版权说明，适配当前依赖和 gVisor 报文头。


## 补丁自动迁移

补丁无法直接应用时，使用 `patches/bases/` 中记录的原始源码做三方合并，保留不冲突的上游修改；不使用 API，也不猜测接口或逻辑变化。迁移候选必须重新编译，并通过 FreeBSD 中 system、gvisor、mixed 三种 TUN 栈的启动和清理测试，才会保存到主分支并发布。发生冲突、编译失败或测试失败时停止发布，下次定时检查重试。实际网络转发测试覆盖 IPv4/IPv6 的 TCP 和 UDP；自动路由仍需实际设备验证。

每次迁移仅尝试一次，不降低测试要求。修改补丁时需同步更新对应基线和校验值；基线不匹配会停止迁移。测试通过前候选补丁仅保存在本次 Actions artifact 中。

## 实际 TUN 流量测试

发布前，对 system、gvisor、mixed 每种栈执行相同的真实网络测试：FreeBSD VNET jail 中运行独立 TCP/UDP 回显服务，测试客户端的 FIB 1 主机路由强制走 tun9，代理的 FIB 0 出站经 epair 到服务端。测试不依赖公共网站。

- IPv4 和 IPv6：TCP 256 KiB 往返、UDP 64/1200/4096 字节往返，随机载荷逐字节校验。
- 暂停代理时，同样的路由下 TCP/UDP 请求必须失败，防止绕过 TUN。
- 抓包验证 TUN 上两种协议、两种地址族的请求和响应；检查路由确实指向 tun9。
- 退出后确认 TUN 设备清理。任何一项失败均阻止保存迁移补丁和发布。

Actions 的 `tun-network-tests` artifact 保存 JSON 校验结果、服务日志、路由记录与 pcap。该测试验证手工路由下的转发，不等同于真实 pfSense/OPNsense 环境的自动路由、防火墙规则或性能测试。
