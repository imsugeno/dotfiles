// MCP servers for GUI tools (Cursor, etc.)
local home = std.extVar('HOME');

{
  mcpServers: {
    'playwright-mcp': {
      command: 'npx',
      args: ['@playwright/mcp@latest'],
    },
    deepwiki: {
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
