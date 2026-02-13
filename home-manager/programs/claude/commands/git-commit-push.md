## Git Commit & Push

変更をコミットしてリモートに push します。

### 手順

#### 1. コミット

[git-commit.md](./git-commit.md) の手順に従いコミットする。

#### 2. Push

1. `git push` でリモートに push
2. リモートブランチが未設定の場合は `git push -u origin <現在のブランチ名>` を使用

### 注意

- コミットする変更がない場合は push のみ実行する（未 push のコミットがある場合）
- コミットも未 push コミットもない場合はその旨を報告する
