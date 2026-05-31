.PHONY: help all switch update clean gc rebuild check mcp clean-mcp claude-code add-skill

# ホスト名の自動検出
HOSTNAME := $(shell scutil --get LocalHostName)

# Default target: MCP設定をビルドしてからnix-darwinを適用
all: mcp switch

# Help
help:
	@echo "Nix-darwin configuration management"
	@echo ""
	@echo "Available commands:"
	@echo "  make          - Build MCP config and apply nix-darwin configuration"
	@echo "  make switch   - Apply the nix-darwin configuration"
	@echo "  make mcp      - Build MCP server configurations from jsonnet"
	@echo "  make claude-code - Install/update Claude Code native binary from GitHub Releases"
	@echo "  make add-skill URL=<github-url> - Install a Claude Code skill from a public GitHub repo"
	@echo "  make update   - Update flake inputs (nixpkgs, nix-darwin, home-manager)"
	@echo "  make rebuild  - Update inputs and apply configuration"
	@echo "  make check    - Check flake configuration"
	@echo "  make clean    - Remove old generations"
	@echo "  make gc       - Garbage collection (clean + collect)"
	@echo ""
	@echo "First time setup:"
	@echo "  1. Copy secrets: cp home-manager/programs/mcp/secrets.jsonnet.example home-manager/programs/mcp/secrets.jsonnet"
	@echo "  2. Edit secrets: vi home-manager/programs/mcp/secrets.jsonnet"
	@echo "  3. Run 'make' from this directory"

# Apply configuration
switch: claude-code
	@# sudo で darwin-rebuild を実行する際、root の git が本リポジトリを信頼できるようにする
	@REPO_PATH="$$(pwd)"; \
	if ! sudo git config --global --get-all safe.directory 2>/dev/null | grep -qFx "$$REPO_PATH"; then \
		echo "Adding $$REPO_PATH to root's git safe.directory..."; \
		sudo git config --global --add safe.directory "$$REPO_PATH"; \
	fi
	sudo darwin-rebuild switch --flake ".#$(HOSTNAME)"

# Install/update Claude Code native binary from GitHub Releases
claude-code:
	./scripts/install-claude-code.sh

# Install a Claude Code skill from a public GitHub repo
# Usage: make add-skill URL=https://github.com/<owner>/<repo>/tree/<ref>/<path-to-skill-dir>
add-skill:
	@[ -n "$(URL)" ] || (echo "Usage: make add-skill URL=https://github.com/<owner>/<repo>/tree/<ref>/<path>" >&2; exit 2)
	deno run --allow-net --allow-read --allow-write scripts/add-skill.ts "$(URL)"

# Build MCP server configurations
mcp: clean-mcp
	jsonnet --ext-str HOME="$$HOME" home-manager/programs/mcp/mcp-general.jsonnet > home-manager/programs/mcp/.mcp-general.json
	jsonnet --ext-str HOME="$$HOME" home-manager/programs/mcp/mcp-claude-code.jsonnet > home-manager/programs/mcp/.mcp-claude-code.json
	jq 'del(.mcpServers) + $$mcp[0]' ~/.config/claude/.claude.json --slurpfile mcp home-manager/programs/mcp/.mcp-claude-code.json > ~/.config/claude/.claude.json.tmp && mv ~/.config/claude/.claude.json.tmp ~/.config/claude/.claude.json

clean-mcp:
	rm -f home-manager/programs/mcp/.mcp-general.json
	rm -f home-manager/programs/mcp/.mcp-claude-code.json

# Update flake inputs
update:
	nix flake update

# Update and rebuild
rebuild: update mcp switch

# Check flake configuration
check:
	nix flake check

# Clean old generations (keep last 5)
clean:
	sudo nix-env --delete-generations +5
	nix-env --delete-generations +5

# Garbage collection
gc: clean
	nix-collect-garbage -d

# Show current system generation
info:
	darwin-rebuild --list-generations