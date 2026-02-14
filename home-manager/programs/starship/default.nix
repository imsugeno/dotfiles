{ config, pkgs, lib, ... }:

let
  dotfilesPath = "${config.home.homeDirectory}/repos/github.com/imsugeno/dotfiles";
in
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  xdg.configFile."starship.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/starship/starship.toml";
  };
}
