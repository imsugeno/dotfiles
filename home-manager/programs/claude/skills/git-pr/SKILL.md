---
name: git-pr
description: feature ブランチの作成からPR作成までを一貫して実行
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

### 3. Push & PR 作成

1. `git push -u origin <ブランチ名>` でリモートに push
2. `gh pr create` で PR を作成:
   - `--base` にステップ1で記録したベースブランチを指定
   - タイトル: 70文字以内で変更内容を要約
   - 本文: `## Summary` に変更内容の箇条書き
3. PR の URL を表示

## 注意

- コミットする変更もpushする変更もない場合は、PR 作成不要とユーザーに報告する
