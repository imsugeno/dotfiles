{ config, dotfilesPath, ... }:

{
  # Claude configuration management
  # Uses symlinks to manage configuration files from dotfiles repository

  # settings.json を動的生成
  home.file.".config/claude/settings.json".text = builtins.toJSON {
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
    };
  };

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