## Gemini Search

Gemini CLIを使用してウェブ検索を実行し、結果を取得してください。

### 手順

1. ユーザーの質問を英語の検索クエリに変換
2. Gemini CLIの非インタラクティブモードで検索を実行
3. 検索結果を分析して日本語で要約・回答

### コマンド実行

```bash
gemini -p "WebSearch: <英語の検索クエリ>"
```

### 重要な指示

- **検索は必ず英語で実行してください**（より正確で豊富な情報が得られます）
- **回答は必ず日本語で提供してください**

### 使用例

ユーザーの質問: 「Reactのベストプラクティスを教えて」
```bash
gemini -p "WebSearch: React hooks best practices 2024"
```
→ 結果を日本語で説明

ユーザーの質問: 「このエラーの解決方法は？」
```bash
gemini -p "WebSearch: TypeError cannot read property undefined JavaScript"
```
→ 解決方法を日本語で提示

ユーザーの質問: 「Nix flakesの設定方法」
```bash
gemini -p "WebSearch: Nix flakes home-manager configuration guide"
```
→ 設定方法を日本語で解説

### オプション

- `-p`: 非インタラクティブモード（プロンプトを直接実行）
- `WebSearch:`: Geminiに検索実行を指示するプレフィックス

### 注意事項

- 検索クエリは英語で、技術用語はそのまま使用
- 最新の情報が必要な場合は年を含める（例: "2024"）
- バージョン情報を含めると精度が向上

### 検索結果の活用

1. 英語の検索結果から重要な情報を抽出
2. 技術用語は適切に日本語化または併記
3. 複数のソースを確認して信頼性を担保
4. 日本語で分かりやすく構造化して回答