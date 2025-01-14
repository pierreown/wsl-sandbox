# sandbox

sandbox 是一个 Linux 环境的沙盒工具脚本，用于在隔离的环境中运行 Linux 命令。可用于测试、开发和演示等场景，如搭建临时编译环境。

### 安装

要安装 `sandbox`，请运行以下命令：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/pierreown/sandbox-script/main/install.sh)"
```

使用 CDN 加速：(可能会因为 CDN 缓存影响导致脚本版本不一致)

```bash
bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/pierreown/sandbox-script@main/install.sh)" -- --cdn
```

### 用法

```bash
sandbox                 # 在隔离的环境中启动 SHELL
sandbox [command]       # 在隔离的环境中执行命令
sandbox /sbin/init      # 在隔离的环境中启动 init 进程
```

-   每条 sandbox 命令都是临时且相互隔离的，命令退出后会自动销毁其环境。
-   沙盒环境支持嵌套一次（两层）

### 针对 wsl 的功能

WSL2 目前已支持启动 systemd，本脚本提供另一种启动方式。同时也支持启动非 systemd 的 init 进程。

```bash
# linux
wsl-init enable                                 # 开启 /sbin/init 自启动
wsl-init disable                                # 禁用 /sbin/init 自启动
# windows
wsl -d {distribution} wsl-init enable           # 开启 /sbin/init 自启动
wsl -d {distribution} wsl-init disable          # 禁用 /sbin/init 自启动
```

-   开启 wsl-init 后，依然可以使用 sandbox 命令。

-   开启 wsl-init 后, `wsl -d {distribution}` 会自动进入 wsl-init 命名空间。

-   开启 wsl-init 后, 如不想进入 wsl-init 命名空间, 可在宿主机中使用 `wsl -d {distribution} bash` 进入原始命名空间。

-   使用中遇到问题，可在宿主机中使用 `wsl -d {distribution} wsl-init disable` 禁用 wsl-init。
