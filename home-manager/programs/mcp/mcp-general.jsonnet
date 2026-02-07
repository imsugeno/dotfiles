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
  },
}
