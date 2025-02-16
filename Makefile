##@ Variables

# Detect architecture and OS
ARCH := $(shell uname -m)
OS := $(shell uname -s)

# Nix configuration system
NIX_SYSTEM := $(shell if [ "$(OS)" = "Darwin" ] && [ "$(ARCH)" = "arm64" ]; then \
		echo "aarch64-darwin"; \
	elif [ "$(OS)" = "Darwin" ] && [ "$(ARCH)" = "x86_64" ]; then \
		echo "x86_64-darwin"; \
	elif [ "$(OS)" = "Linux" ] && [ "$(ARCH)" = "x86_64" ]; then \
		echo "x86_64-linux"; \
	elif [ "$(OS)" = "Linux" ] && [ "$(ARCH)" = "aarch64" ]; then \
		echo "aarch64-linux"; \
	else \
		echo "unsupported"; \
	fi)
NIX_CONFIG_TYPE := $(shell if [ "$(OS)" = "Darwin" ]; then \
		echo "darwinConfigurations"; \
	else \
		echo "nixosConfigurations"; \
	fi)
NIX_ENV := $(shell . ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null || echo "not_found")
NIX_FLAGS := --extra-experimental-features 'flakes nix-command'

# User's home directory
HOME_DIR := $(shell echo $$HOME)
CONFIG_DIR := $(HOME_DIR)/.config

# Darwin-rebuild path
DARWIN_REBUILD := $(shell command -v darwin-rebuild 2>/dev/null || echo "./result/sw/bin/darwin-rebuild")

##@ Help

# Default target
.PHONY: default
default: help

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  install      - Set up full environment"
	@echo "  build        - Build Nix configuration"
	@echo "  switch       - Apply Nix configuration"
	@echo "  update       - Update Nix flake and configurations"
	@echo "  format       - Format Nix files"
	@echo "  format-check - Check Nix formatting"
	@echo "  pr           - Create and push a PR (usage: make pr m='commit message' b='branch-name' t='PR title')"

##@ General

.PHONY: install
install: setup update

.PHONY: build
build: nix-build

.PHONY: check
check: nix-check

.PHONY: format
format: nix-format

.PHONY: setup
setup: nix-setup

.PHONY: switch
switch: nix-switch

.PHONY: update
update: nix-update

##@ Nix Setup

.PHONY: nix-setup
nix-setup: nix-install nix-check nix-connect 

.PHONY: nix-connect
nix-connect:
	@echo "🔌 Verifying Nix daemon socket..."
	@if [ -S /nix/var/nix/daemon-socket/socket ]; then \
		echo "✅ Nix daemon is already active!"; \
	else \
		if [ "$(OS)" = "Darwin" ]; then \
			echo "🍎 Launching Nix daemon on macOS..."; \
			sudo launchctl load -w /Library/LaunchDaemons/org.nixos.nix-daemon.plist; \
		elif [ "$(OS)" = "Linux" ]; then \
			echo "🐧 Launching Nix daemon on Linux..."; \
			sudo systemctl start nix-daemon.service; \
		else \
			echo "Unsupported OS: $(OS)"; \
			exit 1; \
		fi; \
		sleep 3; \
		echo "✅ Nix daemon connection established!"; \
	fi

.PHONY: nix-check
nix-check:
	@echo "🔍 Verifying Nix environment setup..."
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "❌ Nix environment not found. Please ensure Nix is installed and run:"; \
		exit 1; \
	fi
	@echo "✅ Nix environment found!"

.PHONY: nix-install
nix-install:
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "🚀 Installing Nix environment..."; \
		curl -L https://nixos.org/nix/install | sh; \
	fi
	@echo "✅ Nix environment installed!"

##@ Nix

.PHONY: nix-update
nix-update: nix-build nix-switch

.PHONY: nix-backup
nix-backup:
	@echo "🗄️ Backing up configuration files..."
	@backup_dir="$$HOME/.config/backups/$(shell date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$backup_dir"; \
	if [ -d "$$HOME/.config" ]; then \
		cp -R "$$HOME/.config" "$$backup_dir/" 2>/dev/null || true; \
		echo "✅ Backup created at $$backup_dir"; \
	fi

.PHONY: nix-build
nix-build:
	@echo "🏗️ Building Nix configuration..."
	@if [ "$$CI" = "true" ]; then \
		echo "Running in CI"; \
		if [ "$(OS)" = "Darwin" ]; then \
			nix build .#$(NIX_CONFIG_TYPE).runner.system $(NIX_FLAGS) --show-trace; \
		else \
			nix run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- build --flake .#runner; \
		fi; \
	else \
		if [ "$(NIX_SYSTEM)" = "unsupported" ]; then \
			echo "❌ Unsupported system architecture: $(OS) $(ARCH)"; \
			exit 1; \
		fi; \
		if [ "$(OS)" = "Darwin" ]; then \
			nix build .#$(NIX_CONFIG_TYPE).$(NIX_SYSTEM).system $(NIX_FLAGS) --show-trace; \
		else \
			nix run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- build --flake .#$(NIX_SYSTEM); \
		fi; \
	fi
	@echo "✅ Nix configuration built successfully!"

.PHONY: nix-flake-update
nix-flake-update: nix-connect
	@echo "♻️ Refreshing flake.lock file..."
	@if [ "$$CI" = "true" ]; then \
		echo "Bypassing flake update in CI"; \
	else \
		nix flake update $(NIX_FLAGS); \
	fi
	@echo "✅ flake.lock updated!"

.PHONY: nix-format
nix-format:
	@echo "🧹 Formatting Nix files..."
	@nix fmt
	@echo "✅ Formatting complete"

.PHONY: nix-format-check
nix-format-check:
	@echo "🔍 Checking Nix file formatting..."
	@nix fmt -- --fail-on-change
	@echo "✅ All Nix files are properly formatted"

.PHONY: nix-switch
nix-switch:
	@echo "🔧 Activating Nix configuration..."
	@if [ "$$CI" = "true" ]; then \
		if [ "$(OS)" = "Darwin" ]; then \
			$(DARWIN_REBUILD) switch --flake .#runner; \
		else \
			nix run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- switch --flake .#runner || \
			echo "Nix switch failed in CI for $(NIX_SYSTEM), ignoring..."; \
		fi; \
	else \
		if [ "$(OS)" = "Darwin" ]; then \
			nix build .#darwinConfigurations.$(NIX_SYSTEM).system; \
			$(DARWIN_REBUILD) switch --flake .#$(NIX_SYSTEM); \
		else \
			sudo nixos-rebuild switch --flake .#$(NIX_SYSTEM); \
		fi; \
	fi
	@echo "✅ Configuration applied successfully!"

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
	@echo "🚀 Creating PR branch and pushing changes..."
	@git checkout -b feature/$(b)
	@git add .
	@git commit -m "$(m)"
	@git push -u origin feature/$(b)
	@echo "📬 Initiating pull request creation..."
	@if [ -z "$(t)" ]; then \
		gh pr create --fill; \
	else \
		gh pr create --title "$(t)" --body "$(m)"; \
	fi
	@echo "✅ PR created successfully!"
