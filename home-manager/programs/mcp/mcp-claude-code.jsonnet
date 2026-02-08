// MCP servers for Claude Code CLI
local home = std.extVar('HOME');

{
  mcpServers: {
    deepwiki: {
      type: 'http',
      url: 'https://mcp.deepwiki.com/mcp',
    },
    serena: {
      command: home + '/.local/share/mise/installs/python/3.14/bin/uvx',
      args: [
        '--from',
        'git+https://github.com/oraios/serena',
        'serena',
        'start-mcp-server',
      ],
    },
  },
}
