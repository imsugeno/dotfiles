{ config, lib, dotfilesPath, ... }:

let
  baseSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    language = "Japanese";
    alwaysThinkingEnabled = true;
    # alwaysThinkingEnabled = true でも showThinkingSummaries のデフォルトは false のため
    # インタラクティブセッションでは thinking block が redacted 表示となる。意図と揃える。
    showThinkingSummaries = true;
    autoMemoryEnabled = false;
    # v2.1.111 で Opus 4.7 向けに追加された `xhigh`（`high` と `max` の中間）。
    # alwaysThinkingEnabled = true と合わせて、Opus 4.7 の推論深度を引き上げる。
    effortLevel = "xhigh";
    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      # v2.1.83 で追加。Bash / hooks / MCP stdio サーバーのサブプロセス env から
      # Anthropic・クラウドプロバイダーのクレデンシャルを剥奪する。deny ルールで
      # 守っている .env / ~/.ssh / ~/.aws / secrets.jsonnet と同じ防御思想の defense-in-depth。
      CLAUDE_CODE_SUBPROCESS_ENV_SCRUB = "1";
    };
    # `includeCoAuthoredBy` は deprecated。attribution 設定で commit / pr 双方の帰属表示を空文字列化して抑止する。
    attribution = {
      commit = "";
      pr = "";
    };
    enabledPlugins = {
      "typescript-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "gopls-lsp@claude-plugins-official" = true;
    };
    permissions = {
      defaultMode = "bypassPermissions";
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
        "Bash(cat *)"
        "Bash(head *)"
        "Bash(tail *)"
        "Bash(wc *)"
        "Bash(sort *)"
        "Bash(uniq *)"
        "Bash(diff *)"
        "Bash(grep *)"
        "Bash(find *)"
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
      Stop = [{
        matcher = "";
        hooks = [{
          type = "command";
          command = "${dotfilesPath}/home-manager/programs/claude/hooks/notify.ts";
        }];
      }];
      PermissionRequest = [{
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

  # settings.json を動的生成
  home.file.".config/claude/settings.json".text = builtins.toJSON settings;

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