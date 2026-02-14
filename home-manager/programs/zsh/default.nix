{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    # Enable autocompletions
    enableCompletion = true;

    # Shell aliases
    shellAliases = {
      ll = "ls -l";
      la = "ls -a";
      lla = "ls -la";
      sl = "ls";
    };

    # Initialize with .zshrc content
    initContent = builtins.readFile ./.zshrc;
  };

  # Copy zsh config files
  home.file.".zsh" = {
    source = ./zsh-config;
    recursive = true;
  };
}