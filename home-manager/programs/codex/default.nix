{ config, dotfilesPath, ... }:
{
  # Codex configuration management
  # Keep runtime data (auth, sessions, caches, plugins) under ~/.codex unmanaged.

  home.file.".codex/config.toml" = {
    force = true;
    source = config.lib.file.mkOutOfStoreSymlink
      "${dotfilesPath}/home-manager/programs/codex/config.toml";
  };

  home.file.".codex/AGENTS.md" = {
    force = true;
    source = config.lib.file.mkOutOfStoreSymlink
      "${dotfilesPath}/home-manager/programs/codex/AGENTS.md";
  };

  home.file.".codex/rules/default.rules" = {
    force = true;
    source = config.lib.file.mkOutOfStoreSymlink
      "${dotfilesPath}/home-manager/programs/codex/rules/default.rules";
  };
}
