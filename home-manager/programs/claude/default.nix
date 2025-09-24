{ config, ... }:

{
  # Claude configuration management
  # Uses symlinks to manage configuration files from dotfiles repository

  home.file.".config/claude/CLAUDE.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/github.com/imsugeno/dotfiles/home-manager/programs/claude/CLAUDE.md";
  };

  home.file.".config/claude/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/github.com/imsugeno/dotfiles/home-manager/programs/claude/settings.json";
  };

  home.file.".config/claude/commands" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/github.com/imsugeno/dotfiles/home-manager/programs/claude/commands";
  };

  home.file.".config/claude/hooks" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/github.com/imsugeno/dotfiles/home-manager/programs/claude/hooks";
  };
}