.PHONY: help switch update clean gc rebuild check

# Default target
help:
	@echo "Nix-darwin configuration management"
	@echo ""
	@echo "Available commands:"
	@echo "  make switch   - Apply the nix-darwin configuration"
	@echo "  make update   - Update flake inputs (nixpkgs, nix-darwin, home-manager)"
	@echo "  make rebuild  - Update inputs and apply configuration"
	@echo "  make check    - Check flake configuration"
	@echo "  make clean    - Remove old generations"
	@echo "  make gc       - Garbage collection (clean + collect)"
	@echo ""
	@echo "First time setup:"
	@echo "  1. Run 'make switch' from this directory"
	@echo "  2. Then 'sudo rm -rf /etc/nix-darwin' to remove old config"

# Apply configuration
switch:
	darwin-rebuild switch --flake ".#imsugeno"

# Update flake inputs
update:
	nix flake update

# Update and rebuild
rebuild: update switch

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