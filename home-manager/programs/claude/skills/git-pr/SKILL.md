---
name: git-pr
description: feature ブランチの作成からPR作成までを一貫して実行
model: sonnet[1m]
arguments: true
---

feature ブランチの作成からPR作成までを一貫して行います。

## 引数

- `$ARGUMENTS`: ブランチ名（省略可。git-feature に渡される）

## 手順

### 1. Feature ブランチの作成

1. 現在のブランチを記録する（= PR のベースブランチ）
2. git-feature の手順に従い、feature ブランチを作成する（`$ARGUMENTS` をブランチ名として渡す）

### 2. コミット

1. `git status` で未コミットの変更を確認
2. 変更がなければこのステップをスキップ
3. 変更がある場合は git-commit の手順に従いコミットする
4. 複数の論理的に独立した変更がある場合は、分割してコミットする

### 3. Push 状況の確認 → 必要ならユーザーに依頼

このユーザー環境では `git push` は permission deny される前提。Claude 側で push を試行しない。**まずローカルとリモートの HEAD を比較し、既に push 済みならスキップする。**

1. リモートの最新を取得: `git fetch origin <ブランチ名> 2>/dev/null || true`
2. ローカルとリモートの HEAD を比較:
   ```sh
   LOCAL=$(git rev-parse HEAD)
   REMOTE=$(git rev-parse origin/<ブランチ名> 2>/dev/null || echo "none")
   ```
3. 分岐:
   - **`LOCAL == REMOTE`**: 既に push 済み。何もせず次のステップへ進む
   - **リモートブランチが存在しない、または `LOCAL != REMOTE`**: 未 push / 追加コミットあり。ユーザーに以下を依頼する:
     ```
     以下のコマンドを実行して push してください:
     git push -u origin <ブランチ名>
     ```
     ユーザーから push 完了の応答を受け取るまで次のステップに進まない

### 4. PR テンプレートと規約の確認

PR 本文は **リポジトリ固有のテンプレート・規約に従う** こと。以下の順で確認する:

1. **PR テンプレートの探索**（最初に見つかったものを使用）:
   - `.github/PULL_REQUEST_TEMPLATE.md`
   - `.github/pull_request_template.md`
   - `.github/PULL_REQUEST_TEMPLATE/` 配下の各種テンプレート（複数ある場合はユーザーに選択を仰ぐ）
   - `docs/PULL_REQUEST_TEMPLATE.md`
   - リポジトリ直下の `PULL_REQUEST_TEMPLATE.md` / `pull_request_template.md`
2. **PR 規約の確認**:
   - `CONTRIBUTING.md` / `.github/CONTRIBUTING.md`
   - `CLAUDE.md`（プロジェクト直下/`.github/` 等）に PR 規約の記載がないか
3. **過去 PR の参照**（テンプレートが見つからない場合のフォールバック）:
   - `gh pr list --state merged --limit 5 --json title,body` で直近のマージ済み PR を確認
   - タイトル prefix（`feat:`, `fix:`, `chore:` 等）や本文構造の慣習を把握する
4. **テンプレートも規約も見つからない場合**: シンプルな `## Summary`（変更点の箇条書き）+ `## Test plan`（検証手順のチェックリスト）で作成する

### 5. PR 作成

1. `gh pr create` で PR を作成:
   - `--base` にステップ1で記録したベースブランチを指定
   - `--title`: 70文字以内で変更内容を要約。リポジトリの慣習に従い prefix（`feat:` / `fix:` 等）を付ける
   - `--body`: ステップ4で取得したテンプレートを埋めた本文。HEREDOC で渡すこと
   - テンプレートのチェックボックス・セクションは **実際の変更内容に基づいて埋める**（空欄や `<!-- ... -->` プレースホルダを残さない。該当しない項目は「N/A」と明記）
2. PR 作成後、`gh pr view --web` ではなく URL を標準出力に表示する

## 注意

- コミットする変更もpushする変更もない場合は、PR 作成不要とユーザーに報告する
- `git push` は **Claude が実行しない**。常にユーザーに依頼する
- PR テンプレートのコメント（`<!-- ... -->`）は本文に残さず削除する
