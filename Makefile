##@ Variables

# Detect OS
OS := $(shell uname -s)

# Ensure Nix environment is sourced
NIX_ENV := $(shell . ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null || echo "not_found")

# User's home directory
HOME_DIR := $(shell echo $$HOME)
CONFIG_DIR := $(HOME_DIR)/.config

# Nix experimental features
NIX_FLAGS := --extra-experimental-features 'flakes nix-command'

##@ Help

# Default target
.PHONY: default
default: help

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  install      - Set up full environment"
	@echo "  switch       - Apply Nix configuration"
	@echo "  update       - Update Nix flake and configurations"
	@echo "  format       - Format Nix files"
	@echo "  format-check - Check Nix formatting"
	@echo "  pr           - Create and push a PR (usage: make pr m='commit message' b='branch-name' t='PR title')"

##@ General

.PHONY: install
install: nix-install

.PHONY: check
check: nix-check

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
nix-update: nix-flake-update nix-switch

.PHONY: nix-flake-update
nix-flake-update:
	@echo "🔄 Updating flake.lock..."
	@nix flake update $(NIX_FLAGS)
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

.PHONY: nix-switch
nix-switch:
	@echo "🔄 Applying Nix configuration..."
	@if [ "$$CI" = "true" ]; then \
		nix build .#darwinConfigurations.runner.system $(NIX_FLAGS) --show-trace; \
	else \
		nix build .#darwinConfigurations.aarch64-darwin.system $(NIX_FLAGS) --show-trace; \
	fi
	@./result/sw/bin/darwin-rebuild switch --flake .#aarch64-darwin
	@echo "✨ Configuration applied successfully!"

##@ GitHub

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
