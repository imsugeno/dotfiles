# CLAUDE.md

日本語で応答してください。

## プロジェクト概要

macOS (aarch64-darwin) 向けの dotfiles リポジトリ。Nix Flakes + nix-darwin + home-manager で宣言的にシステムとユーザー環境を管理する。

## 技術スタック

- **Nix Flakes**: パッケージ管理・システム構成の基盤
- **nix-darwin**: macOS システム設定・Homebrew パッケージの宣言的管理
- **home-manager**: ユーザーレベルの設定ファイル管理（symlink 方式）
- **Jsonnet**: MCP サーバー設定の生成（secrets は .gitignore で除外）
- **Make**: ビルド・デプロイの統一インターフェース

## ディレクトリ構成

```
flake.nix                    # Flake 定義（inputs/outputs）
Makefile                     # make switch / make mcp / make update 等
nix-darwin/default.nix       # macOS システム設定 + Homebrew
home-manager/
  home.nix                   # home-manager エントリポイント（imports）
  programs/
    claude/                  # Claude Code 設定・フック・コマンド
    cursor/                  # Cursor IDE 設定（settings.json, keybindings.json）
    karabiner/               # Karabiner-Elements 設定
    mcp/                     # MCP サーバー設定（jsonnet → JSON 生成）
    git/                     # Git 設定
    zsh/                     # Zsh 設定
    deno/                    # Deno 設定
```

## よく使うコマンド

```bash
make switch    # nix-darwin 設定を適用（sudo 必要）
make mcp       # MCP 設定を jsonnet からビルド
make update    # flake inputs を更新
make rebuild   # update + mcp + switch
make check     # flake 設定を検証
```

## 開発ルール

- **設定ファイルの管理方式**: home-manager の `home.file` または `xdg.configFile` で `mkOutOfStoreSymlink` を使い、リポジトリ内のファイルへ symlink を張る
- **新しいプログラム設定を追加する場合**: `home-manager/programs/<name>/default.nix` を作成し、`home-manager/home.nix` の imports に追加する
- **Homebrew パッケージ**: `nix-darwin/default.nix` の `homebrew.brews` / `homebrew.casks` にアルファベット順で追加する
- **シークレット**: `secrets.jsonnet` は `.gitignore` で除外。`secrets.jsonnet.example` をテンプレートとして管理する
- **新規ファイル追加時**: Nix Flakes は Git 追跡ファイルのみ参照するため、`git add` を忘れないこと
- **Determinate Nix**: `nix.enable = false` を設定して競合を回避している
