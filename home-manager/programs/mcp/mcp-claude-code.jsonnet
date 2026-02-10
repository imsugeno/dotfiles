// MCP servers for Claude Code CLI
local home = std.extVar('HOME');
local secrets = import 'secrets.jsonnet';

{
  mcpServers: {
    devin: {
      type: 'http',
      url: 'https://mcp.devin.ai/mcp',
      headers: {
        Authorization: 'Bearer ' + secrets.devin.apiKey,
      },
    },
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
