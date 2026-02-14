{ config, dotfilesPath, ... }:
{
  # Visual Studio Code configuration management
  # Uses symlinks to manage settings from dotfiles repository

  home.file."Library/Application Support/Code/User/settings.json" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${dotfilesPath}/home-manager/programs/vscode/settings.json";
  };
}
