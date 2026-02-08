{ config, dotfilesPath, ... }:
{
  home.file.".config/mise/config.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/mise/config.toml";
  };
  home.file."mise.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/mise/mise.toml";
  };
  home.file.".default-python-packages" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/mise/.default-python-packages";
  };
  home.file.".default-go-packages" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/mise/.default-go-packages";
  };
}
