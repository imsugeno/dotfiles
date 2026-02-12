{ config, lib, dotfilesPath, hostname, ... }:

let
  baseSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    env.DISABLE_AUTOUPDATER = "1";
    includeCoAuthoredBy = false;
    permissions.defaultMode = "bypassPermissions";
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

  settings = if hostname == "kazusa-sugeno"
    then lib.recursiveUpdate baseSettings bedrockSettings
    else baseSettings;
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

  home.file.".config/claude/hooks" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/claude/hooks";
  };
}