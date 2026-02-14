{ config, lib, dotfilesPath, ... }:

let
  baseSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    env.DISABLE_AUTOUPDATER = "1";
    includeCoAuthoredBy = false;
    permissions = {
      defaultMode = "acceptEdits";
      allow = [
        # Read — 全ファイル読み取り許可（deny で機密ファイルを除外）
        "Read"
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
      Notification = [{
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
  };

  bedrockSettings = {
    awsAuthRefresh = "aws sso login --profile claude-code";
    env = {
      ANTHROPIC_BEDROCK_BASE_URL = "https://bedrock-runtime.us-west-2.amazonaws.com";
      ANTHROPIC_MODEL = "us.anthropic.claude-opus-4-6-v1";
      ANTHROPIC_SMALL_FAST_MODEL = "us.anthropic.claude-haiku-4-5-20251001-v1:0";
      AWS_PROFILE = "claude-code";
      AWS_REGION = "us-west-2";
      CLAUDE_CODE_USE_BEDROCK = "1";
      CLAUDE_CODE_MAX_OUTPUT_TOKENS = "20000";
      MAX_THINKING_TOKENS = "1024";
    };
  };

  settings = lib.recursiveUpdate baseSettings bedrockSettings;
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