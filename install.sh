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
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
  # 現在のシェルで nix を有効化
  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
else
  info "Nix: OK"
fi

# ─── リポジトリのクローン ───

# スクリプトの実行場所からリポジトリパスを推定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPECTED_DOTFILES_DIR="$HOME/repos/github.com/imsugeno/dotfiles"

# 既に dotfiles ディレクトリ内で実行されている場合はそれを使用
if [[ -f "${SCRIPT_DIR}/flake.nix" ]]; then
  DOTFILES_DIR="${SCRIPT_DIR}"
  if [[ "${DOTFILES_DIR}" != "${EXPECTED_DOTFILES_DIR}" ]]; then
    error "dotfiles はghq管理下の ${EXPECTED_DOTFILES_DIR} に配置してください"
    exit 1
  fi
  info "既存の dotfiles ディレクトリを使用: ${DOTFILES_DIR}"
else
  DOTFILES_DIR="${EXPECTED_DOTFILES_DIR}"

  if [[ ! -d "${DOTFILES_DIR}" ]]; then
    info "dotfiles をクローンしています..."
    mkdir -p "$(dirname "${DOTFILES_DIR}")"
    git clone https://github.com/imsugeno/dotfiles.git "${DOTFILES_DIR}"
  else
    info "dotfiles ディレクトリは既に存在します: ${DOTFILES_DIR}"
  fi
fi

cd "${DOTFILES_DIR}"

# ─── MCP 設定の初期ダミーファイル ───

MCP_DIR="home-manager/programs/mcp"
for f in .mcp-general.json .mcp-claude-code.json; do
  if [[ ! -f "${MCP_DIR}/${f}" ]]; then
    echo '{}' > "${MCP_DIR}/${f}"
    info "作成: ${MCP_DIR}/${f}"
  fi
done

# ─── nix-darwin の初回セットアップ ───

info "nix-darwin を適用しています (ユーザー: $(id -un))..."
# make switchが初回はsudo nix runへフォールバックし、2回目以降はdarwin-rebuildを使う
make switch

info ""
info "セットアップが完了しました！"
info ""
info "次のステップ:"
info "  1. 新しいターミナルを開く"
info "  2. 各アプリへログインし、必要なmacOS権限を許可する"
