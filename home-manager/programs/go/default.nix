{ pkgs, ... }:

{
  home.packages = with pkgs; [
    go-tools # staticcheck
  ];
}
