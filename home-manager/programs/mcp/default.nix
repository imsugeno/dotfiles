{ config, dotfilesPath, ... }:
{
  # MCP configuration management
  # Generated .mcp-general.json is symlinked to each tool's config path

  # Cursor
  home.file.".cursor/mcp.json" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${dotfilesPath}/home-manager/programs/mcp/.mcp-general.json";
  };
}
