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
nix-update:
	@echo "🔄 Updating all configurations (this may take a while)..."
	@nix run .#update
	@echo "✨ All updates completed!"

.PHONY: nix-clean
nix-clean:
	@echo "Cleaning up..."
	@echo "✨ Cleanup complete"

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

##@ Nix Darwin

.PHONY: nix-darwin
nix-darwin: nix-darwin-install nix-darwin-update

.PHONY: nix-darwin-install
nix-darwin-install:
	@if [ "$(OS)" = "Darwin" ]; then \
		if ! command -v darwin-rebuild >/dev/null 2>&1; then \
			echo "📦 Installing nix-darwin..."; \
			nix run nix-darwin -- switch --flake .#shunkakinoki; \
		fi \
	fi

.PHONY: nix-darwin-update
nix-darwin-update:
	@if [ "$(OS)" = "Darwin" ]; then \
		echo "Updating nix-darwin..."; \
		nix flake update && \
		nix run nix-darwin -- switch --flake .#shunkakinoki; \
	fi

##@ Nix Home Manager

.PHONY: nix-home-manager
nix-home-manager: nix-home-manager-install nix-home-manager-update

.PHONY: nix-home-manager-install
nix-home-manager-install:
	@echo "Installing nix-home-manager..."
	@nix run home-manager -- switch --flake .#shunkakinoki

.PHONY: nix-home-manager-update
nix-home-manager-update:
	@echo "Updating nix-home-manager..."
	@nix flake update
	@nix run home-manager -- switch --flake .#shunkakinoki

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
