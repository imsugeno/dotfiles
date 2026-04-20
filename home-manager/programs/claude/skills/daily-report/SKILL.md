---
name: daily-report
description: 本日の全セッションログを解析し、プロジェクト別の日報を生成
model: opusplan
effort: max
arguments: true
---

本日（または指定日）の全Claude Codeセッションログを解析し、3セクション構成の日報を自動生成する。

## 引数

$ARGUMENTS

- 日付指定（任意）: `YYYY-MM-DD` 形式。省略時は本日。
- 出力先: `~/Work/dailyreport/`

## 処理フロー

### Step 1: セッションログ収集

**格納場所**: CLI 版 / VSCode 拡張 / Cursor 拡張いずれも以下の2箇所に保存される。両方を対象にする。
- `~/.claude/projects/`
- `~/.config/claude/projects/`

**重要な注意点**:
- **maxdepth を制限しない**: worktree 配下のセッションは深い階層に格納される（例: `-Users-canly-src-.../leretto-inc-canly-public-api-nexus-worktrees-feature-CPA-115/xxx.jsonl`）。`-maxdepth 4` のような制限を付けると取りこぼす。
- **ファイル mtime ではなく JSONL 内の `timestamp` でフィルタする**: `find -newer` はファイル修正時刻ベースなので、同じセッションファイルが複数日にまたがる場合や、別日の daily-report 自身によって touch された場合に誤判定する。JSONL の各レコードが持つ `timestamp` フィールド（ISO8601 UTC）が対象日で始まる行を1件でも含むファイルのみを対象にする。
- **サブエージェントを除外**: `/subagents/` パスを含むファイルは親セッションの一部なので重複カウントしない。

```bash
# 対象日 (YYYY-MM-DD、JST ローカル日付) を TARGET_DATE に設定
TARGET_DATE=${ARG:-$(date +%Y-%m-%d)}

python3 - "$TARGET_DATE" <<'PY'
import glob, json, sys
target = sys.argv[1]
paths = (glob.glob('/Users/canly/.claude/projects/**/*.jsonl', recursive=True)
         + glob.glob('/Users/canly/.config/claude/projects/**/*.jsonl', recursive=True))
paths = [p for p in paths if '/subagents/' not in p]
for p in paths:
    try:
        with open(p) as f:
            for line in f:
                try:
                    d = json.loads(line)
                    # timestamp は UTC。JST日報の場合は target 前日 15:00Z〜当日 14:59Z も含めたいなら調整
                    if d.get('timestamp', '').startswith(target):
                        print(p); break
                except Exception:
                    pass
    except Exception:
        pass
PY
```

**JST / UTC の取り扱い**: `timestamp` は UTC。JST の「今日」は UTC では前日 15:00〜当日 14:59 に該当する。厳密に JST ローカル日付で集計したい場合は、対象範囲を `${TARGET_DATE-1}T15:00:00Z` ~ `${TARGET_DATE}T14:59:59Z` に広げて再判定する。ゆるく UTC 日付で集計するだけでよければ上記のままで十分（今日のセッションが UTC 深夜に開始し翌日にまたがる場合のみ影響）。

各セッションファイルから `role == "user"` のメッセージと `role == "assistant"` のテキストを抽出し、以下を特定する:
- プロジェクト名（パスの `-Users-canly-src-github-com-<org>-<repo>` 部分から推定、worktree 配下なら `-worktrees-<branch>` も含める）
- 作業内容（ユーザー指示のうちスキル定義・`<scheduled-task>` 等の自動生成メッセージを除外した実入力）
- 時間帯（`timestamp` の最初と最後）
- セッション件数（日報の規模感把握用）

### Step 2: gitログ補完

セッションに対応するリポジトリで対象日のコミットを取得:

```bash
git -C <repo_path> log --all --format="%h %ai %s | %an" \
  --since="${TARGET_DATE}T00:00:00" --until="${TARGET_DATE}T23:59:59"
```

**注意点**:
- **worktree 配下も個別に走査する**: `canly-public-api-nexus.worktrees/feature/CPA-xxx/` などの別ブランチで作業した内容は親リポジトリの log には出ないことがある。`ls <repo>.worktrees/*/` と `ls <repo>.worktrees/*/*/` を再帰的に見て、`.git` (ファイル) を持つディレクトリを拾う。
- **著者フィルタは使わない**: `claude/xxx` ブランチの Claude リモートエージェントによるコミット（Author: `Claude <noreply@anthropic.com>`）は自分の作業成果として扱いたいので、`--author` で絞らずに後段で判断する。
- **未コミット変更も拾う**: `git status` と `git diff --stat` で作業中の変更を把握し、「明日以降やること」に反映する。

### Step 3: セクション1「履歴」生成

**今日やったこと:**
- プロジェクト別 → 作業カテゴリ別にグルーピング
- 各項目は1行で簡潔に。PR番号があれば記載
- セッション数0のプロジェクトは除外

**明日以降やること:**
- セッションログ内の「TODO」「あとで」「明日」「次は」「残課題」等のキーワードから自動抽出
- セッション中断（`[Request interrupted by user]`）後の未完了タスクも検出

### Step 4: セクション2「インパクト」生成

**対象の選別基準**（全タスクではなく「成果として語れるもの」に限定）:
- PRマージまたは作成があった作業
- 設計判断を伴う作業（技術設計書の作成、アーキテクチャ変更等）
- 調査で結論を出した作業
- typo修正、設定変更のみ、依存関係の自動更新（Renovate等）は**除外**

**各タスクの分析観点:**
- **背景・課題**: ビジネス/技術的問題。コードの詳細には踏み込まない
- **やったこと**: 設計判断・技術選定の「なぜ」を含める
- **難易度**: ★☆☆（定型）/ ★★☆（設計判断）/ ★★★（未知領域・高い不確実性）+ 理由1文
- **インパクト**: チーム・プロダクトへの効果を具体的に

**課題・Next Action**: 各タスクの残課題をまとめる。セクション1の「明日以降やること」と重複する場合は参照で済ませる。

### Step 5: セクション3「レビュー」生成

セッションログのユーザーメッセージ**とアシスタントメッセージ**の両方を分析対象にする。

**全般的な改善ポイント:**
- 手戻り・やり直しのパターン（同じファイルを複数回編集、アプローチ変更）
- 時間がかかった作業の原因分析
- より効率的にできた可能性のある作業フロー

**LLM活用の改善ポイント（4軸）:**
- **CLAUDE.md改善**: プロジェクト固有のルールや知識を追記すれば防げた手戻り
- **Hook活用**: 自動化できる繰り返し操作（フォーマット、lint等）
- **プロンプト改善**: より少ない指示で意図が伝わる表現
- **コンテキスト効率**: 不要な情報の読み込み、エージェントの活用方法

### Step 6: ファイル出力

- パス: `~/Work/dailyreport/YYYY-MM-DD.md`
- 既存ファイルがある場合は上書き確認（scheduled-task 実行時はユーザー不在のため上書き）
- 保存後、内容をユーザーに表示

### Step 7: セルフチェック

出力前に以下を確認する:
- **セッション件数の妥当性確認**: 対象日のセッションファイルが「1件のみ（= daily-report 自身）」の場合、他の場所にセッションファイルがないか再確認する（maxdepth・パス指定のミスが典型原因）。平日で 1 件のみは不自然。
- **git log との突き合わせ**: セッションログに現れないコミット（リモート Claude エージェント作の `claude/xxx` ブランチ等）がある場合、日報本文で「リモート作業」として区別するか、その日のローカル作業量を正しく評価する。
- **worktree 漏れチェック**: 同一リポジトリに複数 worktree が存在する場合、各 worktree の `git status` / `git log` を確認する。メインリポジトリだけ見ると feature ブランチの作業を丸ごと見落とす。

## 出力フォーマット

```markdown
## 日報 - YYYY/MM/DD

### 1. 履歴

#### 今日やったこと

##### <プロジェクト名>
**<作業カテゴリ>**
- 実績（1行で簡潔に）

#### 明日以降やること
- TODO項目

---

### 2. インパクト

#### [タスク名]
- **背景・課題**: ...
- **やったこと**: ...
- **難易度**: ★☆☆〜★★★ + 理由1文
- **インパクト**: ...

#### 課題・Next Action
- 残課題

---

### 3. レビュー

#### 全般
- 改善ポイント

#### LLM活用
- ハーネス・プロンプト改善ポイント
```

## 出力ルール

- 各項目は1〜2文で簡潔に
- 該当がないセクションは丸ごと省略（例: インパクト対象なし、改善ポイントなし）
- インパクトセクションは評価者やチームメンバーが文脈なしで読んで価値が伝わるように書く
- レビューセクションは具体的なアクション（何をどう変えるか）を含める
