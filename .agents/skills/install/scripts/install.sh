#!/usr/bin/env bash
# 从 GitHub release 安装 aliyun-cli（macOS / Linux）到用户级全局路径 ~/.local/bin（无需 sudo）
# 用法: ./scripts/install.sh [版本号]   (默认 v3.5.1 等最新版)
# Windows 请用 install.ps1

set -euo pipefail

REPO="aliyun/aliyun-cli"
VER="${1:-}"

# 获取最新版本号
if [ -z "${VER}" ]; then
  echo ">> 获取最新版本号..."
  VER=$(curl -sL --max-time 30 -A "Mozilla/5.0" -o /dev/null -w '%{url_effective}' \
        "https://github.com/${REPO}/releases/latest" | grep -oE 'v[0-9.]+' | head -1)
fi
[ -n "${VER}" ] || { echo "!! 无法获取版本号"; exit 1; }
echo ">> 目标版本: ${VER}"

# 平台判断
UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"
case "${UNAME_S}" in
  Darwin) OS="macosx";;
  Linux)  OS="linux";;
  *) echo "!! 非 unix 平台，请使用 install.ps1"; exit 1;;
esac
case "${UNAME_M}" in
  x86_64|amd64)   ARCH="amd64";;
  arm64|aarch64)  ARCH="arm64";;
  *) echo "!! 不支持的架构: ${UNAME_M}"; exit 1;;
esac

echo ">> 检测到平台: uname -s=${UNAME_S} uname -m=${UNAME_M}  ->  包后缀 ${OS}-${ARCH}"

FILE="aliyun-cli-${OS}-${VER#v}-${ARCH}.tgz"
URL="https://github.com/${REPO}/releases/download/${VER}/${FILE}"
# 安装到用户级全局路径（无需 sudo，需 ~/.local/bin 在 PATH 中）
INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"

echo ">> 下载 ${URL}"
TMP=$(mktemp -d)
curl -fSL --progress-bar "$URL" -o "$TMP/$FILE"

# 校验 SHASUMS256.txt
echo ">> 校验 SHA256..."
EXPECT=$(curl -sL --max-time 30 -A "Mozilla/5.0" \
        "https://github.com/${REPO}/releases/download/${VER}/SHASUMS256.txt" \
        | grep " ${FILE}$" | awk '{print $1}')
ACTUAL=$(shasum -a 256 "$TMP/$FILE" | awk '{print $1}')
[ "${ACTUAL}" = "${EXPECT}" ] || { echo "!! SHA256 校验失败: ${ACTUAL} != ${EXPECT}"; rm -rf "$TMP"; exit 1; }
echo ">> SHA256 OK"

tar -xzf "$TMP/$FILE" -C "$TMP"
mv "$TMP/aliyun" "$INSTALL_DIR/aliyun"
chmod +x "$INSTALL_DIR/aliyun"
rm -rf "$TMP"

echo ">> 已安装到 $INSTALL_DIR/aliyun"
"$INSTALL_DIR/aliyun" version
