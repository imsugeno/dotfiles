{ config, ... }:
{
  # Cursor IDE configuration management
  # Uses symlinks to manage settings from dotfiles repository

  home.file."Library/Application Support/Cursor/User/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/github.com/imsugeno/dotfiles/home-manager/programs/cursor/settings.json";
  };

  home.file."Library/Application Support/Cursor/User/keybindings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/github.com/imsugeno/dotfiles/home-manager/programs/cursor/keybindings.json";
  };
}
