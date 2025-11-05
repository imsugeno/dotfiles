{ config, pkgs, lib, username, homeDirectory, ... }:

{
  home = {
    inherit username;
    homeDirectory = lib.mkForce homeDirectory;
    stateVersion = "24.11";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Import program-specific configurations
  imports = [
    ./programs/git/default.nix
    ./programs/claude/default.nix
    ./programs/zsh/default.nix
    ./programs/deno/default.nix
  ];
}