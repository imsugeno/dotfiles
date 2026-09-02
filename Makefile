.PHONY: help all prepare switch update clean gc rebuild check mcp clean-mcp claude-code add-skill

# 初回インストール直後の親シェルにはbrew/NixのPATHが反映されないためMake側で補完
export PATH := /opt/homebrew/bin:/nix/var/nix/profiles/default/bin:$(PATH)
NIX_BIN := /nix/var/nix/profiles/default/bin/nix

# OSユーザー名をNix Flakeへ渡す（sudo後のrootを拾わないよう事前に取得）
DOTFILES_USER := $(shell id -un)
EXPECTED_REPO := $(HOME)/repos/github.com/imsugeno/dotfiles

# Default target: nix-darwinとMCP設定を適用
all: switch

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
	@echo "  Run the install command documented in README.md"

# 初回評価用のMCPダミーファイルを用意し、固定したghq配下での実行を保証
prepare:
	@test "$$(git rev-parse --show-toplevel)" = "$(EXPECTED_REPO)" || \
		(echo "dotfiles must be located at $(EXPECTED_REPO)" >&2; exit 1)
	@mkdir -p home-manager/programs/mcp
	@test -f home-manager/programs/mcp/.mcp-general.json || echo '{}' > home-manager/programs/mcp/.mcp-general.json
	@test -f home-manager/programs/mcp/.mcp-claude-code.json || echo '{}' > home-manager/programs/mcp/.mcp-claude-code.json

# Apply configuration
switch: prepare claude-code
	@# sudo で darwin-rebuild を実行する際、root の git が本リポジトリを信頼できるようにする
	@REPO_PATH="$$(pwd)"; \
	if ! sudo git config --global --get-all safe.directory 2>/dev/null | grep -qFx "$$REPO_PATH"; then \
		echo "Adding $$REPO_PATH to root's git safe.directory..."; \
		sudo git config --global --add safe.directory "$$REPO_PATH"; \
	fi
	@test -x "$(NIX_BIN)" || (echo "Nix not found: $(NIX_BIN)" >&2; exit 1)
	@echo "Applying nix-darwin with nix run..."
	/usr/bin/sudo /usr/bin/env DOTFILES_USER="$(DOTFILES_USER)" \
		"$(NIX_BIN)" run nix-darwin -- switch --impure --flake ".#current"
	$(MAKE) mcp

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
	jsonnet home-manager/programs/mcp/mcp-general.jsonnet > home-manager/programs/mcp/.mcp-general.json
	jsonnet home-manager/programs/mcp/mcp-claude-code.jsonnet > home-manager/programs/mcp/.mcp-claude-code.json
	@CLAUDE_JSON="$$HOME/.config/claude/.claude.json"; \
	mkdir -p "$$(dirname "$$CLAUDE_JSON")"; \
	test -f "$$CLAUDE_JSON" || echo '{}' > "$$CLAUDE_JSON"; \
	jq 'del(.mcpServers) + $$mcp[0]' "$$CLAUDE_JSON" \
		--slurpfile mcp home-manager/programs/mcp/.mcp-claude-code.json \
		> "$$CLAUDE_JSON.tmp" && mv "$$CLAUDE_JSON.tmp" "$$CLAUDE_JSON"

clean-mcp:
	rm -f home-manager/programs/mcp/.mcp-general.json
	rm -f home-manager/programs/mcp/.mcp-claude-code.json

# Update flake inputs
update:
	"$(NIX_BIN)" flake update

# Update and rebuild
rebuild: update switch

# Check flake configuration
check:
	DOTFILES_USER="$(DOTFILES_USER)" "$(NIX_BIN)" flake check --impure

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
