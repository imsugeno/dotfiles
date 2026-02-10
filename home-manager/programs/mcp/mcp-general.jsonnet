// MCP servers for GUI tools (Cursor, etc.)
local home = std.extVar('HOME');
local secrets = import 'secrets.jsonnet';

{
  mcpServers: {
    'playwright-mcp': {
      command: 'npx',
      args: ['@playwright/mcp@latest'],
    },
    devin: {
      serverUrl: 'https://mcp.devin.ai/mcp',
      headers: {
        Authorization: 'Bearer ' + secrets.devin.apiKey,
      },
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
