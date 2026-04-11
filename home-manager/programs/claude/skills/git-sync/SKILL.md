---
name: git-sync
description: 現在の変更を退避してブランチを最新化し、変更を復元する
model: sonnet
---

現在の変更を `git stash -u` で退避し、`git pull` でブランチを最新化してから `git stash apply` で変更を復元する。

## 手順

1. `git status` で現在の状態を確認する
2. 変更がある場合は `git stash -u` で退避（未追跡ファイル含む）
3. `git pull` でリモートの最新を取得
4. `git stash apply` で退避した変更を復元
5. コンフリクトが発生した場合は `/git-resolve-conflict` スキルを呼び出す
6. 正常に復元できた場合は `git stash drop` で stash を削除
7. `git status` で最終状態を表示

## 注意

- stash する変更がない場合は `git pull` のみ実行する
- `git stash apply` を使う（`pop` ではない）。復元成功を確認してから `drop` する
- コンフリクト発生時は自己判断で解決せず、`/git-resolve-conflict` に委譲する
