---
name: aliyun-install
description: 安装、升级、验证 aliyun-cli（阿里云命令行工具）并配置凭证与环境变量。CLI 装到用户级全局路径（~/.local/bin），全局 aliyun 命令直接可用。当需要安装 aliyun-cli、配置 AK/SK 凭证、设置 region 时使用。
---

# aliyun-install

安装、升级、验证 aliyun-cli，并配置凭证与环境变量。**CLI 装到用户级全局路径**（macOS/Linux：`~/.local/bin`，无需 sudo），全局 `aliyun` 命令直接可用。

核心原则：**先查 help 再拼命令**，不臆造 API 名与参数。

## 安装 CLI

aliyun-cli 通过 **GitHub 仓库打包的二进制**分发（不走 brew）。

### macOS / Linux（在本 skill 目录）

```bash
cd skills/install && ./scripts/install.sh
```

装到 `~/.local/bin/aliyun`（需该目录在 PATH 中）。

### Windows（在本 skill 目录）

```powershell
cd skills\install; powershell -ExecutionPolicy Bypass -File scripts\install.ps1
```

装到 `%USERPROFILE%\.aliyun\bin\aliyun.exe`（install.ps1 会持久化到用户 PATH）。

### 安装包（以 v3.5.1 为例）

| 平台 | 文件 | 内含 |
|------|------|------|
| macOS | `aliyun-cli-macosx-3.5.1-{amd64,arm64,universal}.tgz` | 根目录 `aliyun` |
| Windows | `aliyun-cli-windows-3.5.1-amd64.zip` | 根目录 `aliyun.exe` |
| Linux | `aliyun-cli-linux-3.5.1-{amd64,arm64}.tgz` | 根目录 `aliyun` |

## 定位 CLI（所有 skill 共用）

全局安装后 `aliyun` 命令直接可用，各 skill 直接调用 `aliyun`，不硬编码路径。

## 环境变量（永久生效，可选）

- **macOS / Linux**：确保 `~/.local/bin` 在 PATH（`~/.zshrc` 加 `export PATH="$HOME/.local/bin:$PATH"`）。
- **Windows**：install.ps1 会把 `bin\` 写入用户 PATH（新终端生效）。

## 凭证配置

```bash
aliyun configure --mode OAuth    # 浏览器 SSO（临时凭证，约 1h 过期）
aliyun configure --mode AK       # 永久 AK/SK（RAM 控制台创建，推荐给 agent）
aliyun configure set --region cn-hangzhou   # 设默认 region
```

或环境变量注入（agent 场景，凭证不落盘）：

```bash
export ALIBABA_CLOUD_ACCESS_KEY_ID=...
export ALIBABA_CLOUD_ACCESS_KEY_SECRET=...
```

> 校验：`aliyun sts GetCallerIdentity` 返回身份即凭证有效。

## 通用用法与铁律

```bash
aliyun <product> help                     # 列出某产品所有 API 命令
aliyun <product> <ApiName> help           # 查看单个 API 的参数
aliyun <product> <ApiName> --param value  # 执行
```

铁律：
1. **动手前必跑 `aliyun <product> <ApiName> help`**，确认参数名，不猜。
2. 不确定 API 名先 `aliyun <product> help`。
3. 输出为 JSON，用 `--output json` 并让结果可被解析。
4. 敏感信息（AK/SK）不写入仓库与命令历史。

## 目录结构

```
skills/install/
├── SKILL.md              # 本文件
├── references/
│   └── install.md        # 安装 + 环境变量完整指南
└── scripts/              # 本 skill 特有脚本
    ├── install.sh        # macOS / Linux 安装（-> ~/.local/bin）
    ├── install.ps1       # Windows 安装
```
