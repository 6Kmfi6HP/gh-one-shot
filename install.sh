#!/bin/bash
set -euo pipefail

# ─── 配置 ───────────────────────────────────────────
# 自动选择安装目录：root 用 /usr/local/bin，普通用户用 ~/.local/bin
if [ "$(id -u)" = "0" ]; then
  INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
else
  INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
  mkdir -p "$INSTALL_DIR"
  # 确保 ~/.local/bin 在 PATH 中
  if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
    export PATH="$INSTALL_DIR:$PATH"
  fi
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# ─── 颜色输出 ────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}==>${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠️  $*${NC}"; }
error()   { echo -e "${RED}❌ $*${NC}"; exit 1; }
success() { echo -e "${GREEN}✅ $*${NC}"; }

# ─── 1. 获取最新版本 ────────────────────────────────
info "获取 gh CLI 最新版本..."
GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
  | grep '"tag_name"' \
  | sed 's/.*"v\([^"]*\)".*/\1/')
[ -z "$GH_VERSION" ] && error "无法获取版本号，请检查网络或 GitHub API 限流"
info "最新版本: v${GH_VERSION}"

# ─── 2. 检测架构 ─────────────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)          GH_ARCH="amd64" ;;
  aarch64|arm64)   GH_ARCH="arm64" ;;
  armv6l|armv7l)   GH_ARCH="armv6" ;;
  i386|i686)       GH_ARCH="386"   ;;
  *) error "不支持的架构: $ARCH" ;;
esac
info "系统架构: $ARCH → $GH_ARCH"

# ─── 3. 下载并解压 ───────────────────────────────────
FILENAME="gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz"
URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${FILENAME}"
info "下载: $URL"
curl -fsSL --retry 3 "$URL" | tar -xz -C "$TMP_DIR" \
  || error "下载失败，请检查网络"

GH_BIN="$TMP_DIR/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh"
[ -x "$GH_BIN" ] || error "二进制文件不存在或无执行权限"

# ─── 4. 安装到目标目录 ───────────────────────────────
info "安装 gh 到 $INSTALL_DIR ..."
cp "$GH_BIN" "$INSTALL_DIR/gh"
chmod +x "$INSTALL_DIR/gh"
success "已安装: $INSTALL_DIR/gh"

# ─── 5. 验证安装 ─────────────────────────────────────
info "验证安装..."
"$INSTALL_DIR/gh" --version && success "gh 可正常执行"

# ─── 6. 认证测试 ─────────────────────────────────────
echo ""
if [ -z "${GITHUB_TOKEN:-}" ]; then
  warn "未设置 GITHUB_TOKEN，跳过认证测试"
  warn "使用方式: export GITHUB_TOKEN=your_token && bash $0"
else
  info "测试 Token 认证..."
  if GITHUB_TOKEN="$GITHUB_TOKEN" "$INSTALL_DIR/gh" auth status 2>&1; then
    success "Token 认证成功"
  else
    error "Token 认证失败，请检查 token 权限或有效期"
  fi
fi

echo ""
info "安装完成！"
if [ "$(id -u)" != "0" ]; then
  warn "非 root 用户，已安装到 $INSTALL_DIR"
  warn "如当前终端找不到 gh 命令，请运行: source ~/.bashrc"
fi
