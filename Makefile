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
install: config-install nix-install darwin-install nix-switch darwin-switch

.PHONY: check
check: nix-check

.PHONY: clean
clean: nix-clean

.PHONY: format
format: nix-format

.PHONY: switch
switch: nix-switch darwin-switch

.PHONY: update
update: nix-update darwin-update

##@ Configuration

.PHONY: config-install
config-install:
	@echo "🔄 Syncing configuration files..."
	@chmod +x sync.sh
	@mkdir -p $(CONFIG_DIR)
	@./sync.sh

##@ Nix
.PHONY: nix-check
nix-check:
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "❌ Nix environment not found. Please ensure Nix is installed and run:"; \
		echo "   source ~/.nix-profile/etc/profile.d/nix.sh"; \
		exit 1; \
	fi
	@if ! command -v home-manager >/dev/null 2>&1; then \
		echo "📦 Home Manager not found. Installing..."; \
		export NIX_PATH=${NIX_PATH:+$NIX_PATH:}$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels && \
		nix-shell '<home-manager>' -A install && \
		echo "✨ Home Manager installed successfully!"; \
	fi

.PHONY: nix-install
nix-install: nix-check nix-backup # nix-switch
	@echo "✨ Installation complete for ${OS}!"

.PHONY: nix-switch
nix-switch: nix-check
	@echo "Applying Home Manager configuration..."
	@. ~/.nix-profile/etc/profile.d/nix.sh && home-manager switch

.PHONY: nix-update
nix-update: nix-check
	@echo "Updating Nix channels..."
	@. ~/.nix-profile/etc/profile.d/nix.sh && nix-channel --update
	@echo "Updating Home Manager..."
	@. ~/.nix-profile/etc/profile.d/nix.sh && home-manager switch

.PHONY: nix-clean
nix-clean:
	@echo "Cleaning up..."
	@echo "✨ Cleanup complete"

.PHONY: nix-format
nix-format:
	@if ! command -v nixpkgs-fmt >/dev/null 2>&1; then \
		echo "❌ nixpkgs-fmt not found. Please run 'make switch' to install it."; \
		exit 1; \
	fi
	@echo "Formatting Nix files..."
	@find . -name "*.nix" -type f -exec nixpkgs-fmt {} +
	@echo "✨ Formatting complete"

.PHONY: nix-format-check
nix-format-check:
	@if ! command -v nixpkgs-fmt >/dev/null 2>&1; then \
		echo "❌ nixpkgs-fmt not found. Please run 'make switch' to install it."; \
		exit 1; \
	fi
	@echo "Checking Nix formatting..."
	@find . -name "*.nix" -type f -exec nixpkgs-fmt --check {} +
	@echo "✅ All Nix files are properly formatted"

##@ GitHub

.PHONY: update
update:
	@if ! command -v gh &> /dev/null; then \
		echo "❌ GitHub CLI not found. Please run 'home-manager switch' to install it."; \
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

##@ Darwin
.PHONY: darwin-install
darwin-install: .config
	@if [ "$(OS)" = "Darwin" ]; then \
		if ! command -v darwin-rebuild >/dev/null 2>&1; then \
			echo "📦 Installing nix-darwin..."; \
			cd $(CONFIG_DIR)/nix && \
			nix build .#darwinConfigurations.shunkakinoki.system; \
			./result/sw/bin/darwin-rebuild switch --flake .#shunkakinoki; \
		fi \
	fi

.PHONY: darwin-switch
darwin-switch:
	@if [ "$(OS)" = "Darwin" ]; then \
		echo "Applying nix-darwin configuration..."; \
		cd $(CONFIG_DIR)/nix && darwin-rebuild switch --flake .#shunkakinoki; \
	fi

.PHONY: darwin-update
darwin-update:
	@if [ "$(OS)" = "Darwin" ]; then \
		echo "Updating nix-darwin..."; \
		cd $(CONFIG_DIR)/nix && \
		nix flake update && \
		darwin-rebuild switch --flake .#shunkakinoki; \
	fi
