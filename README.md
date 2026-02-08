# dotfiles

macOS (Apple Silicon) 向けの dotfiles。Nix Flakes + nix-darwin + home-manager で宣言的にシステム環境を管理する。

## 前提条件

- macOS (aarch64-darwin)
- Xcode Command Line Tools (`xcode-select --install`)

## セットアップ

```bash
bash <(curl -sSL https://raw.githubusercontent.com/imsugeno/dotfiles/main/install.sh)
```

このスクリプトは以下を自動で行う:

1. Homebrew のインストール（未インストールの場合）
2. Determinate Nix のインストール（未インストールの場合）
3. リポジトリを `~/repos/github.com/imsugeno/dotfiles` にクローン
4. MCP シークレットのテンプレートをコピー
5. nix-darwin の初回適用

### セットアップ後

```bash
cd ~/repos/github.com/imsugeno/dotfiles

# MCP シークレットを編集
vi home-manager/programs/mcp/secrets.jsonnet

# MCP 設定をビルド
make mcp
```

## コマンド

| コマンド | 説明 |
|---|---|
| `make` | MCP 設定ビルド + nix-darwin 適用 |
| `make switch` | nix-darwin 設定を適用 |
| `make mcp` | MCP サーバー設定を jsonnet からビルド |
| `make update` | flake inputs を更新 |
| `make rebuild` | update + mcp + switch |
| `make check` | flake 設定を検証 |
| `make clean` | 古い generation を削除 |
| `make gc` | ガベージコレクション |
| `make info` | 現在の generation を表示 |

## 構成

```
flake.nix                          # Flake 定義
Makefile                           # ビルド・デプロイ
nix-darwin/
  default.nix                      # macOS システム設定 + Homebrew パッケージ管理
home-manager/
  home.nix                         # home-manager エントリポイント
  programs/
    claude/                        # Claude Code（設定・フック・コマンド）
    cursor/                        # Cursor IDE（settings.json, keybindings.json）
    karabiner/                     # Karabiner-Elements キーマッピング
    mcp/                           # MCP サーバー設定（Jsonnet）
    git/                           # Git 設定
    zsh/                           # Zsh 設定
    deno/                          # Deno 設定
```
