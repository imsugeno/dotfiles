# dotfiles

macOS (Apple Silicon) 向けの dotfiles。Nix Flakes + nix-darwin + home-manager で宣言的にシステム環境を管理する。

## セットアップ

事前にXcode Command Line Toolsをインストールする。

```bash
xcode-select --install
```

インストール完了後、次を実行する。Homebrew、Determinate Nix、nix-darwin、
Home Manager、Homebrewパッケージ、MCP設定まで順に適用される。

```bash
bash <(curl -sSL https://raw.githubusercontent.com/imsugeno/dotfiles/main/install.sh)
```

dotfilesはghqルートとして固定している `~/repos` 配下へ配置される。

```text
~/repos/github.com/imsugeno/dotfiles
```

OSユーザー名は実行時に取得するため、ホスト名やユーザー名をFlakeへ追加する必要はない。

### 2回目以降

```bash
cd ~/repos/github.com/imsugeno/dotfiles
make switch
```

`make switch` はnix-darwin、Home Manager、Homebrew、MCP設定をまとめて適用する。

### 手動対応が必要なもの

- Slack、Notionなど各アプリへのログイン
- GitHub SSH鍵と `gh auth login`
- macOSのアクセシビリティ、画面収録、入力監視などの権限
- Karabiner-ElementsのSystem Extension許可
- Docker Desktopの初回設定
- Claude Code、Codexなどの認証

Codexの `~/.codex/config.toml` とランタイムデータはdotfilesでは管理しない。

## コマンド

| コマンド | 説明 |
|---|---|
| `make` | nix-darwin適用 + MCP設定ビルド |
| `make switch` | nix-darwin + MCP設定を適用 |
| `make mcp` | MCP サーバー設定を jsonnet からビルド |
| `make update` | flake inputs を更新 |
| `make rebuild` | update + mcp + switch |
| `make check` | flake 設定を検証 |
| `make clean` | 古い generation を削除 |
| `make gc` | ガベージコレクション |
| `make info` | 現在の generation を表示 |
