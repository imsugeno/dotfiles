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
    'awslabs.aws-documentation-mcp-server': {
      command: 'uvx',
      args: ['awslabs.aws-documentation-mcp-server@latest'],
      env: {
        FASTMCP_LOG_LEVEL: 'ERROR',
        AWS_DOCUMENTATION_PARTITION: 'aws',
        MCP_USER_AGENT: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
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
