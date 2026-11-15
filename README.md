# sing-box for FreeBSD x86-64 (TUN)

仅构建 **FreeBSD / amd64（x86-64，GOAMD64=v1）** 的 sing-box，支持 TUN 的 `system`、`gvisor`、`mixed` 栈。不再构建 OpenBSD、Windows、ARM、386、RISC-V 或 reF1nd 分支。

## 构建与下载

主分支 `master` 更新后自动编译，并在 FreeBSD 14.3 amd64 虚拟机检查三种 TUN 栈的启动和退出。检查成功后发布到本仓库 [Releases](https://github.com/Opnwall/Freebsd-box/releases)。也可从 Actions 手动运行。分支及 PR 构建仅上传 Actions artifact。

产物：

- `bsd-box-freebsd-amd64.xz`：兼容原文件名，解压后即 sing-box。
- `SHA256SUMS`：压缩文件的 SHA-256 校验值。
- `build-info.txt`：源码、依赖、Go 版本和编译参数。

当前固定 sing-box **1.14.4** 和 Go **1.27.4**，避免每日追踪上游时补丁失配。更新版本时修改 `build.env`、`.go-version`，并重新验证补丁。只固定目标平台，不裁剪常用代理协议；编译标签见 `build.env`。

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

见 [template.json](template.json)。在 FreeBSD 上以 root 运行，并确保 `if_tun` 可用。默认模板使用 `auto_route: false`，先验证 TUN，再按防火墙实际情况配置路由和 DNS。pfSense / OPNsense 的放行规则及 DNS 需自行配置。

`auto_route: true` 沿用原补丁的独立 FIB 方案，`fib_index` 默认 2022，需要足够的 `net.fibs` 和 `net.add_addr_allfibs=1`；按程序提示配置 `/boot/loader.conf` 后重启。虚拟机启动检查覆盖 `auto_route: false`，不代表已验证真实网关上的自动路由或转发吞吐。

本版本仅包含 FreeBSD TUN 补丁，没有增加原仓库的进程匹配、redirect 或订阅扩展。补丁改编自 [Vincent-Loeng/bsd-box 的 hidden 分支](https://github.com/Vincent-Loeng/bsd-box/tree/hidden)，保留 FreeBSD TUN 代码的 WireGuard/MIT 版权说明，适配当前依赖和 gVisor 报文头。

## Original License

```
Copyright (C) 2022 by nekohasekai <contact-sagernet@sekai.icu>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

In addition, no derivative work may use the name or imply association
with this application without prior consent.
```
