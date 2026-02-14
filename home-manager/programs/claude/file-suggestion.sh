#!/bin/bash
set -euo pipefail

# JSONから検索クエリを抽出
query=$(cat | jq -r '.query // empty')

# クエリが空の場合は全ファイルを返す
if [[ -z "$query" ]]; then
  query="."
fi

# CLAUDE_PROJECT_DIRが設定されていない場合は現在のディレクトリを使用
cd "${CLAUDE_PROJECT_DIR:-.}"

# fd と fzf が利用可能か確認
if ! command -v fd &> /dev/null; then
  echo "Error: fd is not installed" >&2
  exit 1
fi

if ! command -v fzf &> /dev/null; then
  echo "Error: fzf is not installed" >&2
  exit 1
fi

# ファイル検索とフィルタリング
fd --follow --hidden --no-ignore | fzf --filter="$query" | head -20
