#!/bin/bash
set -e

echo "==> 获取 gh CLI 最新版本号..."
GH_VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest \
  | grep '"tag_name"' \
  | sed 's/.*"v\([^"]*\)".*/\1/')

echo "==> 最新版本: v${GH_VERSION}"

# 检测系统架构
ARCH=$(uname -m)
case $ARCH in
  x86_64)  GH_ARCH="amd64" ;;
  aarch64) GH_ARCH="arm64" ;;
  armv6l)  GH_ARCH="armv6" ;;
  armv7l)  GH_ARCH="armv6" ;;
  i386|i686) GH_ARCH="386" ;;
  *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

echo "==> 检测到架构: $ARCH -> $GH_ARCH"

# 下载目录（临时）
TMP_DIR=$(mktemp -d)
FILENAME="gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${FILENAME}"

echo "==> 下载: $DOWNLOAD_URL"
curl -fsSL "$DOWNLOAD_URL" | tar -xz -C "$TMP_DIR"

GH_BIN="$TMP_DIR/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh"

echo "==> 测试 gh 版本..."
$GH_BIN --version

echo ""
echo "==> 测试 GH_TOKEN 认证..."
if [ -z "$GH_TOKEN" ]; then
  echo "⚠️  未设置 GH_TOKEN，跳过认证测试"
  echo "   提示: 运行前先 export GH_TOKEN=your_token"
else
  GH_TOKEN=$GH_TOKEN $GH_BIN auth status && echo "✅ 认证成功" || echo "❌ 认证失败，请检查 token"
fi

echo ""
echo "==> 清理临时目录..."
rm -rf "$TMP_DIR"

echo "==> 完成！如需安装到系统，运行："
echo "    sudo mv \$GH_BIN /usr/local/bin/gh"
