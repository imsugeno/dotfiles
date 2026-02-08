# dotfiles

macOS (Apple Silicon) 向けの dotfiles。Nix Flakes + nix-darwin + home-manager で宣言的にシステム環境を管理する。

## セットアップ

```bash
bash <(curl -sSL https://raw.githubusercontent.com/imsugeno/dotfiles/main/install.sh)
```

### セットアップ後

```bash
cd ~/repos/github.com/imsugeno/dotfiles

# シークレットを編集して設定をビルド
vi home-manager/programs/mcp/secrets.jsonnet
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
