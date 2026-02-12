## Git Feature Branch

現在の変更を退避し、デフォルトブランチを最新化してから新しいfeatureブランチを作成します。

### 引数

- `$ARGUMENTS`: 新しいブランチ名（省略可。省略時は変更内容から自動生成）

### 手順

1. ブランチ名が指定されていない場合は `git diff` と `git status` で変更内容を分析し、`<prefix>/<簡潔な説明>` 形式で自動生成する（例: `feat/add-claude-permission-settings`）。prefix は git-commit.md と同じ規約に従う
2. `git stash -u` で現在の変更（未追跡ファイル含む）を退避
3. `git remote show origin` でデフォルトブランチ名を取得する
4. デフォルトブランチにチェックアウト: `git checkout <デフォルトブランチ>`
5. 最新化: `git pull`
6. 新しいfeatureブランチを作成してチェックアウト: `git checkout -b <ブランチ名>`
7. `git stash pop` で退避した変更を復元
8. 最終状態を `git status` で表示

### 注意

- stash する変更がない場合は stash/pop をスキップする
- stash pop でコンフリクトが発生した場合はユーザーに報告する
- ブランチ名が既に存在する場合はユーザーに確認する
