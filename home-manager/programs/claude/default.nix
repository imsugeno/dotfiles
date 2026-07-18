{ config, lib, pkgs, dotfilesPath, ... }:

let
  baseSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    language = "Japanese";
    alwaysThinkingEnabled = true;
    # alwaysThinkingEnabled = true でも showThinkingSummaries のデフォルトは false のため
    # インタラクティブセッションでは thinking block が redacted 表示となる。意図と揃える。
    showThinkingSummaries = true;
    autoMemoryEnabled = false;
    # v2.1.186 で `!` bash コマンドのデフォルト挙動が context-only から Claude が出力に
    # 対して自動応答する形に変わった。Opus 4.7 + effortLevel = "xhigh" +
    # AGENT_TEAMS / FORK_SUBAGENT + 1h prompt caching の重い構成では、`!ls` や
    # `!git status` のような軽い確認コマンドでも自動で API コールが走るとコストが嵩む。
    # CLAUDE_CODE_DISABLE_FAST_MODE / DISABLE_UPDATES と同じく、意図せぬコスト発生と
    # サイレントな挙動変化を避けるため旧挙動を明示固定する。
    respondToBashCommands = false;
    # v2.1.111 で Opus 4.7 向けに追加された `xhigh`（`high` と `max` の中間）。
    # v2.1.154 で `opus` alias のデフォルト解決先が Opus 4.8 に切り替わり、4.8 のデフォルト
    # effort は `high` になったため、xhigh を明示することで 4.8 でも一段深い推論を引き出す。
    # xhigh は 4.7 / 4.8 双方でサポートされる。alwaysThinkingEnabled = true と合わせて
    # 推論深度を引き上げる。
    effortLevel = "xhigh";
    # v2.1.166 で追加。プライマリモデル (`opus` alias = Opus 4.8) が overloaded / 非リトライ可能な
    # API エラーで利用不能になったとき、優先順に最大 3 つまでのフォールバック先を試す
    # （ターンに対して 1 回リトライ）。v2.1.166 で `--fallback-model` が interactive session にも
    # 適用されるようになったため、Agent Teams + xhigh + 1h cache の重い構成でピーク時に
    # 4.8 が overloaded になっても対話を中断せず Sonnet 4.6 で継続できる。alias で記述することで
    # 将来のモデル世代切替に追従する。
    fallbackModel = [ "sonnet" ];
    env = {
      # v2.1.36+ の Fast Mode（Opus 高速構成）を完全に無効化する。`/fast` コマンドも
      # 「disabled by your organization」相当で弾かれる。v2.1.154 で Opus 4.8 の Fast Mode は
      # 標準 Opus の 2x コスト / 2.5x スピードへ引き下げられたが、依然として標準より高コストで
      # additional usage に直接請求される（プラン枠を消費しない）。誤って /fast を入力した際の
      # 事故的な高コスト発生を未然に防ぐ意図は維持。
      CLAUDE_CODE_DISABLE_FAST_MODE = "1";
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      # v2.1.117 で外部ビルド向けに有効化。サブエージェントを fork して走らせることで
      # CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1" と組み合わせた際に真の並列実行となり、
      # 複数エージェント同時起動時のレイテンシとオーバーヘッドを削減する。
      CLAUDE_CODE_FORK_SUBAGENT = "1";
      # v2.1.83 で追加。Bash / hooks / MCP stdio サーバーのサブプロセス env から
      # Anthropic・クラウドプロバイダーのクレデンシャルを剥奪する。deny ルールで
      # 守っている .env / ~/.ssh / ~/.aws / secrets.jsonnet と同じ防御思想の defense-in-depth。
      CLAUDE_CODE_SUBPROCESS_ENV_SCRUB = "1";
      # v2.1.118 で追加。`DISABLE_AUTOUPDATER` より厳格で `claude update` も含む全更新経路を遮断する。
      # claude-code は scripts/install-claude-code.sh で GitHub Releases から `~/.local/bin/claude` に
      # 配置・更新しているため、内部 autoupdater が走ると dotfiles 管理外の `~/.claude` 配下に
      # 並行インストールが生まれてバージョンの真実の所在が二重化する。dotfiles を単一の真実の所在として固定する。
      DISABLE_UPDATES = "1";
      # v2.1.108 で追加・v2.1.128 で正式対応。プロンプトキャッシュ TTL を 5 分 → 1 時間に延長する。
      # Opus 4.8 (`opus` alias デフォルト) + effortLevel = "xhigh" + AGENT_TEAMS / FORK_SUBAGENT
      # という重い構成では、拡張思考や並列サブエージェントが走る間に 5 分の TTL を簡単に超え、再書き込みコストが嵩む。
      # 1h 書き込みは 5m の 2x コストだが、TTL 内に 2 回再ヒットすれば元が取れる前提で、
      # ユーザーが確認・思考する数分〜数十分のポーズを跨いでもキャッシュが生きる方が正味でメリットが大きい。
      ENABLE_PROMPT_CACHING_1H = "1";
      # v2.1.143 で追加。GitHub から plugin を取得する際の clone を SSH ではなく HTTPS に固定する。
      # `enabledPlugins` で `claude-plugins-official` 配下の typescript-lsp / pyright-lsp / gopls-lsp を
      # 有効化しているため plugin 取得経路の信頼性は実害に直結する。SSH は ~/.ssh のキー設定・
      # known_hosts・GitHub 側の鍵登録に依存し、新規マシンや CI / 一時環境では揃わない可能性がある。
      # `DISABLE_UPDATES = "1"` で更新経路の真実の所在を Homebrew / GitHub Releases に固定したのと同じく、
      # plugin 取得経路も環境差の少ない HTTPS に固定し、運用の予測可能性を高める defense-in-depth。
      CLAUDE_CODE_PLUGIN_PREFER_HTTPS = "1";
    };
    # `includeCoAuthoredBy` は deprecated。attribution 設定で commit / pr 双方の帰属表示を空文字列化して抑止する。
    # v2.1.183 で追加された `sessionUrl` は web / Remote Control セッションからの commit / PR に
    # `Claude-Session: https://claude.ai/code/...` トレーラーを付与する独立フラグで、`commit` / `pr`
    # の空文字列化では塞げない。公式ドキュメント (https://code.claude.com/docs/en/settings#attribution-settings)
    # でも「all attribution を隠すには `commit` / `pr` を空文字 + `sessionUrl = false`」と明記されており、
    # 三者を揃えて attribution 抑止の意図を完結させる。
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };
    enabledPlugins = {
      "typescript-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "gopls-lsp@claude-plugins-official" = true;
    };
    # v2.1.133 で追加・v2.1.143 でデフォルトが "head" → "fresh" (origin/<default>) に変更された。
    # Agent tool の `isolation: "worktree"` / `--worktree` / `EnterWorktree` 起動時、
    # デフォルトの "fresh" だと未push のローカル commits を含まない origin/<default> から
    # worktree が作成され、作業中の WIP が agent 側に渡らない。
    # サブエージェント並列実行（AGENT_TEAMS / FORK_SUBAGENT）で in-progress な変更を
    # そのまま渡したい運用なので、"head" で旧挙動を明示固定する。
    # autoupdate 経路（DISABLE_UPDATES=1 で塞いでいるが Homebrew 経由の昇格は走る）で
    # サイレントに挙動が変わるのを防ぐ。
    worktree = {
      baseRef = "head";
    };
    # v2.1.136 で追加。`permissions.defaultMode = "auto"` の auto mode 分類器に対し、
    # user intent / allow 例外に関係なく無条件で拒否させる自然言語ルール。
    # `permissions.deny` の構文ベース（`Bash(sudo *)` 等）はシェル経由の回避
    # （`bash -lc "sudo ..."` 等）で抜けうるため、同じ defense-in-depth 思想を意図ベースで二重化する。
    # `$defaults` で組み込みルールを継承する。
    autoMode = {
      # v2.1.193 で追加。auto mode 中に narrow な Bash / PowerShell allow ルール
      # （`Bash(sed *)` / `Bash(chmod *)` 等）を分類器の前段で通さず、全ての shell
      # コマンドを classifier に評価させる。auto mode のデフォルトは `Bash(*)` 等の
      # 広い allow のみを停止し、narrow allow は素通しするため、`Bash(sed *)` は
      # `sed -i` で任意ファイルを書き換えうるし `Bash(chmod *)` は `chmod +s` で
      # setuid を付与しうる。`permissions.deny` は構文一致、`hard_deny` はシェル
      # ラッパー経由の回避を意図ベースで拒否するのに対し、`classifyAllShell` は
      # narrow allow の「意図しない引数」の抜け道を classifier 評価で塞ぐ第三の
      # 層。トレードオフとして classifier 呼び出しが増えるが、xhigh + 1h キャッシュ
      # の構成では受容範囲、かつ予測可能性の方が価値が高い。auto mode 外では
      # 通常通り allow が働くため運用摩擦は限定的。
      classifyAllShell = true;
      hard_deny = [
        "$defaults"
        "Never read .env, .env.local, or any other .env.* files in any directory"
        "Never read files under ~/.ssh, ~/.aws, or any secrets.jsonnet file"
        "Never run sudo or su commands, even via shell wrappers, subshells, or pipes"
        "Never run git push — the user pushes manually"
      ];
    };
    permissions = {
      defaultMode = "auto";
      allow = [
        # 読み取り・検索 — 全ファイル許可（deny で機密ファイルを除外）
        "Read"
        "Glob"
        "Grep"
        "WebSearch"
        # Bash — 安全な開発コマンド
        "Bash(git *)"
        "Bash(make *)"
        "Bash(nix *)"
        "Bash(mise *)"
        "Bash(brew *)"
        "Bash(jq *)"
        "Bash(jsonnet *)"
        "Bash(ls *)"
        "Bash(wc *)"
        "Bash(sort *)"
        "Bash(uniq *)"
        "Bash(diff *)"
        "Bash(which *)"
        "Bash(echo *)"
        "Bash(pwd)"
        "Bash(env)"
        "Bash(sw_vers)"
        "Bash(uname *)"
        "Bash(date *)"
        "Bash(gh *)"
        "Bash(osascript *)"
        "Bash(defaults *)"
        "Bash(chmod *)"
        "Bash(mkdir *)"
        "Bash(touch *)"
        "Bash(cp *)"
        "Bash(cd *)"
        "Bash(sed *)"
        "Bash(awk *)"
        # MCP — 現在設定中のサーバーを全許可
        "mcp__devin"
        "mcp__awslabs_aws-documentation-mcp-server"
        "mcp__deepwiki"
        "mcp__serena"
      ];
      deny = [
        "Bash(git push*)"
        "Bash(sudo *)"
        "Bash(su *)"
        "Read(.env)"
        "Read(.env.*)"
        "Read(~/.ssh/**)"
        "Read(~/.aws/**)"
        "Read(**/secrets.jsonnet)"
      ];
    };
    hooks = {
      # `Stop` は各ターン終了ごとに発火するため、CLAUDE_CODE_FORK_SUBAGENT による fork 起動・
      # 受け取りの中間ターンでも通知が走り、マルチエージェント時の S/N 比が悪化していた。
      # `Notification` は Claude Code が能動的にユーザーへ知らせたい状況（メイン完了の
      # idle_prompt、権限要求の permission_prompt、認証成功、MCP elicitation 等）でのみ
      # 発火する。サブエージェント完了は `SubagentStop` 側に振り分けられるため、
      # `Notification` のみ登録すれば望ましいタイミングだけ通知を受け取れる。
      Notification = [{
        matcher = "";
        hooks = [{
          type = "command";
          command = "${dotfilesPath}/home-manager/programs/claude/hooks/notify.ts";
        }];
      }];
      PostToolUse = [{
        matcher = "Edit|Write";
        hooks = [{
          type = "command";
          command = "${dotfilesPath}/home-manager/programs/claude/hooks/go-fmt.sh";
        }];
      }];
    };
    statusLine = {
      type = "command";
      command = "${dotfilesPath}/home-manager/programs/claude/statusline/statusline.ts";
    };
    fileSuggestion = {
      type = "command";
      command = "${dotfilesPath}/home-manager/programs/claude/file-suggestion.sh";
    };
  };

  settings = baseSettings;
in
{
  # Claude configuration management
  # Uses symlinks to manage configuration files from dotfiles repository

  # settings.json は `claude plugin install` 等が runtime に書き換えるため、
  # /nix/store 配下の immutable file への symlink では EACCES で失敗する。
  # activation script で書き込み可能な実ファイルとして配置し、
  # `enabledPlugins` は既存ファイルからマージして runtime 追加分を保持する。
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    TARGET="$HOME/.config/claude/settings.json"
    TMP="$TARGET.tmp"
    BASE=${lib.escapeShellArg (builtins.toJSON settings)}

    # 旧 home.file 管理時の symlink が残っていれば外す
    if [ -L "$TARGET" ]; then
      $DRY_RUN_CMD rm "$TARGET"
    fi

    # 既存ファイルから enabledPlugins を取り出して保持する（runtime install 分を失わないため）
    EXISTING_PLUGINS='{}'
    if [ -f "$TARGET" ]; then
      EXISTING_PLUGINS=$(${pkgs.jq}/bin/jq -c '.enabledPlugins // {}' "$TARGET" 2>/dev/null || echo '{}')
    fi

    $DRY_RUN_CMD ${pkgs.jq}/bin/jq --argjson existing "$EXISTING_PLUGINS" \
      '.enabledPlugins = (.enabledPlugins + $existing)' <<< "$BASE" > "$TMP"
    $DRY_RUN_CMD mv "$TMP" "$TARGET"
    $DRY_RUN_CMD chmod 644 "$TARGET"
  '';

  home.file.".config/claude/CLAUDE.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/claude/CLAUDE.md";
  };

  home.file.".config/claude/commands" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/claude/commands";
  };

  home.file.".config/claude/skills" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/claude/skills";
  };

  home.file.".config/claude/hooks" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/claude/hooks";
  };
}