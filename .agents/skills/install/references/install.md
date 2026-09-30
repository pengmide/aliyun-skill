# 安装 + 环境变量指南

安装 aliyun-cli 到用户级全局路径并配置环境变量，覆盖 macOS / Linux 与 Windows。CLI 通过 GitHub 打包的二进制分发。

---

## 1. 安装 aliyun-cli

脚本自动：获取最新版本 → 按平台/架构选包 → 下载 → 比对 `SHASUMS256.txt` 校验 SHA256 → 安装。

### macOS / Linux

```bash
cd skills/install && ./scripts/install.sh
```

目标：`~/.local/bin/aliyun`（无需 sudo）。

### Windows

```powershell
cd skills\install; powershell -ExecutionPolicy Bypass -File scripts\install.ps1
```

目标：`%USERPROFILE%\.aliyun\bin\aliyun.exe`。

## 2. 配置环境变量（永久生效）

### macOS / Linux

确保 `~/.local/bin` 在 PATH（`~/.zshrc` 末尾追加）：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

生效：`source ~/.zshrc`

### Windows

运行一次：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install.ps1
```

新终端生效。

## 3. 配置凭证

```bash
aliyun configure --mode AK       # 永久 AK/SK（推荐）
aliyun configure --mode OAuth    # 浏览器 SSO（临时）
aliyun configure set --region cn-hangzhou
aliyun sts GetCallerIdentity     # 校验
```

## 4. 验证

```bash
command -v aliyun      # ~/.local/bin/aliyun
aliyun version         # 3.5.1 等
```

## 5. 卸载 / 重新安装

```bash
rm -f ~/.local/bin/aliyun
cd skills/install && ./scripts/install.sh
```
