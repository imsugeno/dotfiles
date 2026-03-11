{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    # Enable autocompletions
    enableCompletion = true;

    # Shell aliases
    shellAliases = {
      ls = "eza --icons --git";
      ll = "eza --icons --git -l";
      la = "eza --icons --git -a";
      lla = "eza --icons --git -la";
      lt = "eza --icons --git --tree";
      sl = "eza --icons --git";
      cafe = "caffeinate -dimsu";
      gpp = "git pull origin main && git push origin HEAD";
      restart = "exec $SHELL -l";
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