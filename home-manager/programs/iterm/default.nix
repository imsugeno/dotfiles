{ config, dotfilesPath, ... }:

{
  # iTerm2 Dynamic Profile
  # https://iterm2.com/documentation-dynamic-profiles.html

  home.file."Library/Application Support/iTerm2/DynamicProfiles/profile.json" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/home-manager/programs/iterm/profile.json";
  };
}
