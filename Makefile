##@ Variables

# Detect OS
OS := $(shell uname -s)

# Ensure Nix environment is sourced
NIX_ENV := $(shell . ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null || echo "not_found")

# User's home directory
HOME_DIR := $(shell echo $$HOME)
CONFIG_DIR := $(HOME_DIR)/.config

##@ Help

# Default target
.PHONY: default
default: help

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  install       - Set up full environment"
	@echo "  switch       - Apply Home Manager and Darwin configuration"
	@echo "  update       - Update Nix channels and configurations"
	@echo "  clean        - Clean up temporary files"
	@echo "  format       - Format Nix files"
	@echo "  format-check - Check Nix formatting"
	@echo "  backup       - Backup existing configurations"
	@echo "  pr           - Create and push a PR (usage: make pr m='commit message' b='branch-name' t='PR title')"

##@ General

.PHONY: install
install: nix-install 

.PHONY: check
check: nix-check

.PHONY: clean
clean: nix-clean

.PHONY: format
format: nix-format

.PHONY: update
update: nix-update

##@ Nix
.PHONY: nix-check
nix-check:
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "❌ Nix environment not found. Please ensure Nix is installed and run:"; \
		exit 1; \
	fi

.PHONY: nix-install
nix-install: nix-check nix-update
	@echo "✨ Installation complete for ${OS}!"

.PHONY: nix-update
nix-update: nix-flake-update nix-run-update

.PHONY: nix-clean
nix-clean:
	@echo "Cleaning up..."
	@echo "✨ Cleanup complete"

.PHONY: nix-flake-update
nix-flake-update:
	@echo "🔄 Updating flake.lock..."
	@nix flake update
	@echo "✨ flake.lock updated!"

.PHONY: nix-format
nix-format:
	@if ! command -v nixpkgs-fmt >/dev/null 2>&1; then \
		echo "❌ nixpkgs-fmt not found. Please run 'make install' to install it."; \
		exit 1; \
	fi
	@echo "Formatting Nix files..."
	@find . -name "*.nix" -type f -exec nixpkgs-fmt {} +
	@echo "✨ Formatting complete"

.PHONY: nix-format-check
nix-format-check:
	@if ! command -v nixpkgs-fmt >/dev/null 2>&1; then \
		echo "❌ nixpkgs-fmt not found. Please run 'make install' to install it."; \
		exit 1; \
	fi
	@echo "Checking Nix formatting..."
	@find . -name "*.nix" -type f -exec nixpkgs-fmt --check {} +
	@echo "✅ All Nix files are properly formatted"

.PHONY: nix-run-update
nix-run-update:
	@echo "🔄 Running update..."
	@nix run .#update
	@echo "✨ Update complete!"

##@ Nix Darwin

.PHONY: nix-darwin
nix-darwin: nix-darwin-install nix-darwin-update

.PHONY: nix-darwin-install
nix-darwin-install: nix-darwin-update
	@echo "Installing nix-darwin..."
	@echo "Installed nix-darwin"

.PHONY: nix-darwin-update
nix-darwin-update:
	@if [ "$(OS)" = "Darwin" ]; then \
		echo "Updating nix-darwin..."; \
		if [ "$$CI" = "true" ]; then \
			nix run --extra-experimental-features "nix-command flakes" nix-darwin -- switch --flake .#runner; \
		else \
			nix run --extra-experimental-features "nix-command flakes" nix-darwin -- switch --flake .#shunkakinoki; \
		fi; \
	fi
	@echo "Updated nix-darwin"

##@ Nix Home Manager

.PHONY: nix-home-manager
nix-home-manager: nix-home-manager-install nix-home-manager-update

.PHONY: nix-home-manager-install
nix-home-manager-install: nix-home-manager-update
	@echo "Installing nix-home-manager..."
	@echo "Installed nix-home-manager"

.PHONY: nix-home-manager-update
nix-home-manager-update: nix-home-manager-install
	@echo "Updating nix-home-manager..."
	@if [ "$$CI" = "true" ]; then \
		nix run --extra-experimental-features "nix-command flakes" home-manager -- switch --flake .#runner; \
	else \
		nix run --extra-experimental-features "nix-command flakes" home-manager -- switch --flake .#shunkakinoki; \
	fi
	@echo "Updated nix-home-manager"

#@ GitHub

.PHONY: pr
pr:
	@if ! command -v gh &> /dev/null; then \
		echo "❌ GitHub CLI not found. Please run 'make install' to install it."; \
		exit 1; \
	fi
	@if [ -z "$(b)" ]; then \
		echo "❌ Branch name required. Usage: make pr m='commit message' b='branch-name' t='PR title'"; \
		exit 1; \
	fi
	@if [ -z "$(m)" ]; then \
		echo "❌ Commit message required. Usage: make pr m='commit message' b='branch-name' t='PR title'"; \
		exit 1; \
	fi
	@echo "Creating PR branch and pushing changes..."
	@git checkout -b feature/$(b)
	@git add .
	@git commit -m "$(m)"
	@git push -u origin feature/$(b)
	@echo "Creating PR..."
	@if [ -z "$(t)" ]; then \
		gh pr create --fill; \
	else \
		gh pr create --title "$(t)" --body "$(m)"; \
	fi
	@echo "✨ PR created successfully!"
