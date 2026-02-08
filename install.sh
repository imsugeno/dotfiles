#!/bin/bash
set -euo pipefail

# ─── 色付き出力 ───

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── 前提チェック ───

if [[ "${OSTYPE}" != darwin* ]]; then
  error "このスクリプトは macOS 専用です"
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  error "Apple Silicon (aarch64) が必要です"
  exit 1
fi

# Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
  error "Xcode Command Line Tools がインストールされていません"
  info "実行してください: xcode-select --install"
  exit 1
fi
info "Xcode Command Line Tools: OK"

# ─── Homebrew ───

if ! command -v brew &>/dev/null; then
  info "Homebrew をインストールしています..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  info "Homebrew: OK"
fi

# ─── Determinate Nix ───

if ! command -v nix &>/dev/null; then
  info "Determinate Nix をインストールしています..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  # 現在のシェルで nix を有効化
  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
else
  info "Nix: OK"
fi

# ─── リポジトリのクローン ───

DOTFILES_DIR="$HOME/repos/github.com/imsugeno/dotfiles"

if [[ ! -d "${DOTFILES_DIR}" ]]; then
  info "dotfiles をクローンしています..."
  mkdir -p "$(dirname "${DOTFILES_DIR}")"
  git clone https://github.com/imsugeno/dotfiles.git "${DOTFILES_DIR}"
else
  info "dotfiles ディレクトリは既に存在します: ${DOTFILES_DIR}"
fi

cd "${DOTFILES_DIR}"

# ─── MCP シークレット ───

MCP_SECRETS="home-manager/programs/mcp/secrets.jsonnet"
if [[ ! -f "${MCP_SECRETS}" ]]; then
  info "MCP シークレットのテンプレートをコピーしています..."
  cp "${MCP_SECRETS}.example" "${MCP_SECRETS}"
  warn "MCP シークレットを編集してください: ${DOTFILES_DIR}/${MCP_SECRETS}"
fi

# ─── MCP 設定の初期ダミーファイル ───

MCP_DIR="home-manager/programs/mcp"
for f in .mcp-general.json .mcp-claude-code.json; do
  if [[ ! -f "${MCP_DIR}/${f}" ]]; then
    echo '{}' > "${MCP_DIR}/${f}"
    info "作成: ${MCP_DIR}/${f}"
  fi
done

# ─── nix-darwin の初回セットアップ ───

info "nix-darwin を適用しています..."
nix run nix-darwin -- switch --flake ".#imsugeno"

info ""
info "セットアップが完了しました！"
info ""
info "次のステップ:"
info "  1. 新しいターミナルを開く"
info "  2. MCP シークレットを編集: vi ${DOTFILES_DIR}/${MCP_SECRETS}"
info "  3. MCP 設定をビルド: cd ${DOTFILES_DIR} && make mcp"
