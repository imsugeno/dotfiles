---
name: daily-report
description: 本日の全セッションログを解析し、プロジェクト別の日報を生成
model: opusplan
effort: max
arguments: true
---

本日（または指定日）の全Claude Codeセッションログを解析し、プロジェクト別の日報を生成する。

## 引数

$ARGUMENTS

- 日付指定（任意）: `YYYY-MM-DD` 形式。省略時は本日。
- 出力先: `~/Work/dailyreport/`

## 処理フロー

### 1. セッションログの収集

以下の手順で対象日のセッションを収集する:

```bash
# 対象日のマーカーを作成（引数の日付 or 本日）
touch -t ${TARGET_DATE}0000 /tmp/dailyreport_marker

# 全プロジェクトのセッションファイルを取得（サブエージェント除外）
find ~/.claude/projects -maxdepth 2 -name "*.jsonl" \
  -newer /tmp/dailyreport_marker ! -path "*/subagents/*"
```

### 2. ユーザーメッセージの抽出

各セッションファイルから `"type":"user"` のメッセージを抽出し、以下を特定する:
- プロジェクト名（パスから推定）
- 作業内容（ユーザーの指示内容から要約）
- 時間帯（ファイルの更新時刻）

### 3. gitログの補完

セッションに対応するリポジトリが存在する場合、対象日のgitログも取得して成果を補完する:

```bash
git -C <repo_path> log --oneline --since="${TARGET_DATE}T00:00:00" --all
```

### 4. 日報の作成

以下のフォーマットで日報を生成する:

```markdown
## 日報 - YYYY/MM/DD

### <プロジェクト名1>

**<作業カテゴリ>**
- やったこと（箇条書き、1行で簡潔に）
- PR番号があれば記載

### <プロジェクト名2>
...
```

**ルール:**
- 長文禁止。各項目は1行で簡潔に。
- 作業カテゴリでグルーピングする（例: ドキュメント整備、機能追加、レビュー対応など）
- PRのマージ・作成があれば番号を記載
- セッション数が0のプロジェクトは除外

### 5. ファイル出力

生成した日報を以下に保存する:
- パス: `~/Work/dailyreport/YYYY-MM-DD.md`
- 既存ファイルがある場合は上書き確認する

最後に日報の内容をユーザーに表示する。
