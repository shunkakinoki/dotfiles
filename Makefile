##@ Variables

SHELL := bash

# Include dotagents from submodule but keep the local targets authoritative.
DOTAGENTS_SKIP_HELP := 1
DOTAGENTS_SKIP_SYNC := 1
-include dotagents/Makefile

# Detect architecture and OS
ARCH := $(shell uname -m)
OS := $(shell uname -s)

# Git variables
GIT_REMOTE_ORIGIN_URL := $(shell git config --get remote.origin.url)
GITHUB_REPO_PATH := $(shell echo $(GIT_REMOTE_ORIGIN_URL) | sed -n 's/.*github.com[:/]\(.*\)\.git/\1/p')
GITHUB_REPO_OWNER := $(shell echo $(GITHUB_REPO_PATH) | cut -d'/' -f1)
GITHUB_REPO_NAME := $(shell echo $(GITHUB_REPO_PATH) | cut -d'/' -f2)
GIT_COMMIT_SHA := $(shell git rev-parse --short HEAD)

# Env ironment variables
NIX_ALLOW_UNFREE := NIXPKGS_ALLOW_UNFREE=1

# Docker image names
DOCKER_IMAGE_NAME_BASE := ghcr.io/$(GITHUB_REPO_OWNER)/$(GITHUB_REPO_NAME)
DOCKER_IMAGE_LATEST := $(DOCKER_IMAGE_NAME_BASE):latest
DOCKER_IMAGE_TAGGED := $(DOCKER_IMAGE_NAME_BASE):$(GIT_COMMIT_SHA)

# Nix executable path
NIX_EXEC := $(shell which nix)

# Common cache settings (only applied when user is trusted to avoid warnings)
NIX_SUBSTITUTERS := https://cache.nixos.org https://devenv.cachix.org https://cachix.cachix.org https://hyprland.cachix.org
NIX_TRUSTED_KEYS := cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=
NIX_CACHIX_CONF := /etc/nix/cachix.conf
# Check if user is trusted (to avoid "ignoring untrusted substituter" warnings)
NIX_USER_TRUSTED := $(shell grep -qE "trusted-users.*=.*(\\*|$(shell whoami))" /etc/nix/nix.conf 2>/dev/null && echo "yes" || echo "no")

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
NIX_CONFIG_TYPE := $(shell \
	if [ "$(OS)" = "Darwin" ]; then \
		echo "darwinConfigurations"; \
	elif [ "$(OS)" = "Linux" ]; then \
		if [ "$$CI" = "true" ] && [ -n "$(NIX_CONFIG_TARGET)" ]; then \
			if [ "$(NIX_CONFIG_TARGET)" = "nixos" ]; then \
				echo "nixosConfigurations"; \
			else \
				echo "homeConfigurations"; \
			fi; \
		elif [ -f /etc/NIXOS ]; then \
			echo "nixosConfigurations"; \
		else \
			echo "homeConfigurations"; \
		fi; \
	else \
		echo "homeConfigurations"; \
	fi)
NIX_USERNAME := $(shell \
	if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
		echo "runner"; \
	else \
		echo "$(shell whoami)"; \
	fi)
NIX_ENV := $(shell . ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null || . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || command -v nix >/dev/null 2>&1 || echo "not_found")
NIX_FLAGS := --extra-experimental-features 'flakes nix-command' --no-pure-eval --impure
# Only add cache options when user is trusted or on Darwin/CI (avoids "ignoring untrusted substituter" warnings)
ifeq ($(OS),Darwin)
NIX_FLAGS += --option substituters "$(NIX_SUBSTITUTERS)" --option trusted-public-keys "$(NIX_TRUSTED_KEYS)"
else ifeq ($(NIX_USER_TRUSTED),yes)
NIX_FLAGS += --option substituters "$(NIX_SUBSTITUTERS)" --option trusted-public-keys "$(NIX_TRUSTED_KEYS)"
else ifdef CI
NIX_FLAGS += --option substituters "$(NIX_SUBSTITUTERS)" --option trusted-public-keys "$(NIX_TRUSTED_KEYS)"
endif

# Machine detection for automatic host mapping
DETECTED_HOST := $(shell \
	if [ "$(OS)" = "Darwin" ] && [ "$(shell whoami)" = "shunkakinoki" ] && [ "$(ARCH)" = "arm64" ]; then \
		computer_name=$$(scutil --get ComputerName 2>/dev/null || echo ""); \
		if echo "$$computer_name" | grep -q "Shun's MacBook M4"; then \
			echo "galactica"; \
		else \
			echo ""; \
		fi; \
	elif [ "$(OS)" = "Linux" ]; then \
		hostname=$$(hostname 2>/dev/null || echo ""); \
		if [ "$$hostname" = "kyber" ]; then \
			echo "kyber"; \
		elif [ "$$hostname" = "matic" ]; then \
			echo "matic"; \
		else \
			echo ""; \
		fi; \
	else \
		echo ""; \
	fi)

# User's home directory
HOME_DIR := $(shell echo $$HOME)
CONFIG_DIR := $(HOME_DIR)/.config

# Darwin-rebuild path
DARWIN_REBUILD := $(shell command -v darwin-rebuild 2>/dev/null || echo "./result/sw/bin/darwin-rebuild")

# Sudo path (NixOS uses /run/wrappers/bin/sudo)
SUDO := $(shell \
	if command -v sudo >/dev/null 2>&1; then \
		echo "sudo"; \
	elif [ -x /run/wrappers/bin/sudo ]; then \
		echo "/run/wrappers/bin/sudo"; \
	elif [ -x /usr/bin/sudo ]; then \
		echo "/usr/bin/sudo"; \
	else \
		echo "sudo"; \
	fi)

##@ Help

# Default target
.PHONY: default
default: help ## Default target (shows help).

# ====================================================================================
# HELP
# ====================================================================================
.PHONY: help
help: ## Show this help message.
	@echo "Usage: make <target>"
	@echo
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ General

.PHONY: install
install: setup git-submodule-sync nix-build nix-switch shell-install ## Set up full environment (setup, flake-update, build, switch, shell-install).

.PHONY: build
build: nix-build ## Build Nix configuration.

.PHONY: check
check: ## Run all validation checks (nix, format, lua).
	@echo "🔍 Running all validation checks..."
	@$(MAKE) nix-flake-check
	@$(MAKE) nix-format-check
	@$(MAKE) nix-lint
	@$(MAKE) lua-check
	@echo "✅ All checks passed"

.PHONY: flake-check
flake-check: nix-flake-check ## Check Nix flake configuration (alias for nix-flake-check).

.PHONY: format
format: nix-format ## Format Nix files (alias for nix-format).

.PHONY: setup
setup: nix-setup ## Basic Nix setup (alias for nix-setup).

.PHONY: setup-dev
setup-dev: nix-setup git-submodule-sync shell-install ## Set up local development environment (Nix + submodules + shell).

.PHONY: nvim-plugins-install
nvim-plugins-install: ## Download/build missing Neovim native plugin binaries (fff.nvim, telescope-fzf-native, vscode-diff).
	@PACK_DIR="$$HOME/.local/share/nvim/site/pack"; \
	\
	FFF_DIR=""; \
	for d in "$$PACK_DIR"/*/opt/fff.nvim "$$PACK_DIR"/*/start/fff.nvim; do \
		if [ -d "$$d" ]; then FFF_DIR="$$d"; break; fi; \
	done; \
	if [ -n "$$FFF_DIR" ]; then \
		FFF_BINARY="$$FFF_DIR/target/libfff_nvim.so"; \
		if [ ! -f "$$FFF_BINARY" ]; then \
			echo "Downloading fff.nvim native binary..."; \
			FFF_VERSION=$$(git -C "$$FFF_DIR" rev-parse --short HEAD 2>/dev/null || echo ""); \
			if [ -n "$$FFF_VERSION" ]; then \
				_ARCH=$$(uname -m); \
				_LDD=$$(ldd --version 2>&1 || echo ""); \
				if echo "$$_LDD" | grep -q musl; then \
					_TRIPLE="$${_ARCH}-unknown-linux-musl"; \
				else \
					_TRIPLE="$${_ARCH}-unknown-linux-gnu"; \
				fi; \
				mkdir -p "$$FFF_DIR/target"; \
				echo "Fetching https://github.com/dmtrKovalenko/fff.nvim/releases/download/$$FFF_VERSION/$${_TRIPLE}.so"; \
				curl --fail --location --silent --show-error \
					-o "$$FFF_BINARY" \
					"https://github.com/dmtrKovalenko/fff.nvim/releases/download/$$FFF_VERSION/$${_TRIPLE}.so" \
					&& echo "fff.nvim binary downloaded successfully" \
					|| echo "fff.nvim binary download failed"; \
			else \
				echo "fff.nvim: could not determine version, skipping"; \
			fi; \
		else \
			echo "fff.nvim binary already present"; \
		fi; \
	else \
		echo "fff.nvim plugin directory not found, skipping"; \
	fi

.PHONY: switch
switch: nix-switch services nvim-plugins-install dotagents-sync ## Apply Nix configuration, restart services, and sync plugins.

.PHONY: clean
clean: ## Clean up old Nix generations and garbage collect.
	@echo "🧹 Cleaning up old generations and garbage collecting..."
	@$(SUDO) nix-collect-garbage -d
	@echo "✅ Cleanup complete"

.PHONY: reset
reset: git-submodule-sync ## Reset git status to clean (restore all changes and reinitialize submodules).
	@echo "🔄 Resetting git status to clean..."
	@git checkout -- .
	@echo "✅ Git status reset to clean"

.PHONY: services
services: ## Restart platform-specific services (launchd on macOS, systemd on Linux).
	@if [ "$(OS)" = "Darwin" ]; then \
		$(MAKE) launchctl; \
	elif [ "$(OS)" = "Linux" ]; then \
		$(MAKE) systemctl; \
	fi

.PHONY: test
test: neovim-test nix-test shell-test python-test shell-inline-check ## Run all tests (neovim + nix + shell + python + shell-inline-check).

##@ Dev
.PHONY: dev
dev: nix-develop ## Enter the Nix dev shell (alias for nix-develop).

.PHONY: nix-develop
nix-develop: ## Enter the Nix development shell.
	DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS)

.PHONY: devenv-cli
devenv-cli: ## Build the packaged devenv CLI binary.
	@echo "📦 Building packaged devenv CLI..."
	@$(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#devenv-cli $(NIX_FLAGS) --show-trace
	@echo "✅ devenv CLI available in ./result/bin/devenv"

##@ Upgrade

.PHONY: upgrade
upgrade: sync update

.PHONY: upgrade-dev
upgrade-dev: ## Upgrade inside the Nix dev shell (mirrors CI).
	@echo "🔄 Running upgrade inside the Nix dev shell..."
	@DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS) .# --command $(MAKE) upgrade

##@ Sync

.PHONY: sync
sync: dotagents-sync codex-security-sync rtk-rewrite-sync ## Sync all components (dotagents, Codex security patterns, rtk-rewrite.sh).

.PHONY: dotagents-sync
dotagents-sync: ## Sync dotagents (commands, skills, MCP configuration).
	@$(MAKE) -C dotagents sync

.PHONY: codex-security-sync
codex-security-sync: ## Sync Codex security deny patterns from Claude settings.
	@echo "🔒 Syncing Codex security deny patterns..."
	@./scripts/sync-codex-security.sh
	@echo "✅ Codex security patterns synced"

.PHONY: rtk-rewrite-sync
rtk-rewrite-sync: ## Sync rtk-rewrite.sh from upstream rtk repo.
	@echo "🔄 Syncing rtk-rewrite.sh from upstream..."
	@./scripts/sync-rtk-rewrite.sh
	@echo "✅ rtk-rewrite.sh synced"



##@ Update

.PHONY: update
update: nix-update neovim-update gitalias-update llm-update overlays-update  ## Update Nix flake, overlays, Neovim plugins, LLM configs, gitalias, and bun deps

.PHONY: update-lock
update-lock: nix-flake-update bun-update cargo-update ## Update lock files for Nix flake, bun, and Cargo.

.PHONY: bun-update
bun-update: ## Update bun dependencies to latest and regenerate lock file.
	@echo "📦 Updating bun dependencies..."
	@bun update --latest --recursive
	@git checkout bun.lock
	@bun install
	@echo "✅ bun dependencies updated"

.PHONY: cargo-update
cargo-update: ## Update Rust dependencies to latest and regenerate lock file.
	@echo "🦀 Updating Cargo dependencies..."
	@cargo +nightly update --breaking -Z unstable-options
	@echo "✅ Cargo dependencies updated"

.PHONY: gitalias-update
gitalias-update: ## Download latest gitalias.txt from upstream.
	@echo "📥 Updating gitalias.txt..."
	@./scripts/update-gitalias.sh
	@echo "✅ gitalias.txt updated"

.PHONY: llm-update
llm-update: ## Regenerate tool configs from models.json.
	@echo "🤖 Updating LLM tool configs..."
	@./scripts/llm-update.sh
	@echo "✅ LLM configs updated"

.PHONY: overlays-update
overlays-update: ## Upgrade all custom overlays to latest versions.
	@echo "🔄 Upgrading custom overlays..."
	@if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
		echo "⏭️ Skipping overlay upgrade in CI/Docker"; \
	else \
		./scripts/upgrade-overlays.sh all; \
	fi

##@ Nix Setup

.PHONY: nix-setup
nix-setup: nix-install nix-check nix-connect nix-trust ## Set up Nix environment (install, check, connect, trust caches).

.PHONY: nix-connect
nix-connect: ## Ensure Nix daemon is running.
	@echo "🔌 Ensuring Nix daemon is running for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@if [ "$(OS)" = "Darwin" ]; then \
		if nix store info >/dev/null 2>&1; then \
			echo "✅ Nix daemon is already reachable. Skipping restart."; \
		elif [ -f /Library/LaunchDaemons/systems.determinate.nix-daemon.plist ]; then \
			$(SUDO) launchctl bootout system/systems.determinate.nix-daemon 2>/dev/null || true; \
			$(SUDO) launchctl bootstrap system /Library/LaunchDaemons/systems.determinate.nix-daemon.plist; \
		elif [ -f /Library/LaunchDaemons/org.nixos.nix-daemon.plist ]; then \
			$(SUDO) launchctl bootout system/org.nixos.nix-daemon 2>/dev/null || true; \
			$(SUDO) launchctl bootstrap system /Library/LaunchDaemons/org.nixos.nix-daemon.plist; \
		else \
			echo "❌ No Nix daemon plist found"; exit 1; \
		fi; \
	elif [ "$(OS)" = "Linux" ]; then \
		if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ] || [ "$$AUTOMATED_UPDATE" = "true" ]; then \
			echo "🏃‍♂️ Nix daemon management (e.g., systemctl) is skipped in CI/Docker/automated environments."; \
			if [ "$$IN_DOCKER" = "true" ]; then \
				echo "ℹ️ Docker environment is using a single-user Nix installation (no separate daemon)."; \
			fi; \
			if [ "$$AUTOMATED_UPDATE" = "true" ]; then \
				echo "ℹ️ Running in automated update mode - assuming nix-daemon is already running."; \
			fi; \
		else \
			if [ -d /run/systemd/system ] && [ -S /run/systemd/private ]; then \
				if systemctl is-active --quiet nix-daemon.service; then \
					echo "🐧 nix-daemon.service is already running. Skipping restart."; \
				else \
					echo "🐧 nix-daemon.service not running. Attempting to start..."; \
					$(SUDO) systemctl start nix-daemon.service; \
				fi; \
			else \
				echo "🏃‍♂️ systemd not detected as PID 1 or not fully operational. Nix daemon management via systemctl is skipped."; \
				echo "ℹ️ This environment might be using a single-user Nix installation, require manual daemon setup, or be inside a container without full systemd."; \
			fi; \
		fi; \
	else \
		echo "❌ Unsupported OS: $(OS)"; \
		exit 1; \
	fi
	@echo "⏳ Waiting for daemon to initialize..."
	@sleep 3
	@echo "✅ Nix daemon should now be active!"

.PHONY: nix-trust
nix-trust: ## Ensure current user is trusted by the Nix daemon.
	@if [ "$(OS)" = "Linux" ] && [ "$(NIX_USER_TRUSTED)" = "no" ] && [ "$$CI" != "true" ] && [ "$$IN_DOCKER" != "true" ]; then \
		echo "🔐 Adding $(NIX_USERNAME) to trusted-users in /etc/nix/nix.conf"; \
		if grep -q '^trusted-users' /etc/nix/nix.conf 2>/dev/null; then \
			$(SUDO) sed -i 's/^trusted-users.*/trusted-users = root $(NIX_USERNAME)/' /etc/nix/nix.conf; \
		else \
			echo "trusted-users = root $(NIX_USERNAME)" | $(SUDO) tee -a /etc/nix/nix.conf > /dev/null; \
		fi; \
		$(SUDO) systemctl restart nix-daemon.service; \
		echo "✅ $(NIX_USERNAME) is now a trusted Nix user"; \
	fi

.PHONY: nix-check
nix-check: ## Verify Nix environment setup.
	@echo "🔍 Verifying Nix environment setup for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "❌ Nix environment not found. Please ensure Nix is installed and run:"; \
		exit 1; \
	fi
	@echo "✅ Nix environment found!"

.PHONY: nix-install
nix-install: ## Install Nix if not already installed.
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "🚀 Installing Determinate Nix environment for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"; \
		curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm; \
	fi
	@echo "✅ Nix environment installed!"

##@ Nix

.PHONY: nix-update
nix-update: nix-connect nix-daemon-update nix-flake-update ## Upgrade Nix flake, build, and switch.

.PHONY: nix-backup
nix-backup: ## Backup configuration files.
	@echo "🗄️ Backing up configuration files for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@backup_dir="$$HOME/.config/backups/$(shell date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$backup_dir"; \
	if [ -d "$$HOME/.config" ]; then \
		cp -R "$$HOME/.config" "$$backup_dir/" 2>/dev/null || true; \
		echo "✅ Backup created at $$backup_dir"; \
	fi

.PHONY: nix-build
nix-build: nix-connect nix-trust ## Build Nix configuration.
	@echo "🏗️ Building Nix configuration for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
		echo "🤖 Running in CI/Docker environment"; \
		if [ "$(OS)" = "Darwin" ]; then \
			$(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#$(NIX_CONFIG_TYPE).runner.system $(NIX_FLAGS) --impure --no-update-lock-file --show-trace; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			$(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#nixosConfigurations.runner.config.system.build.toplevel $(NIX_FLAGS) --impure --no-update-lock-file --show-trace; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			HOST=$(DETECTED_HOST) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage $(NIX_FLAGS) --impure --no-update-lock-file --show-trace; \
		else \
			echo "Unsupported OS $(OS) for non-CI build"; \
			exit 1; \
		fi; \
	else \
		if [ "$(NIX_SYSTEM)" = "unsupported" ]; then \
			echo "❌ Unsupported system architecture: $(OS) $(ARCH)"; \
			exit 1; \
		elif [ "$(OS)" = "Darwin" ]; then \
			$(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#$(NIX_CONFIG_TYPE).$(NIX_SYSTEM).system $(NIX_FLAGS) --impure --show-trace; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			if [ -n "$(HOST)" ]; then \
				echo "Building named host: $(HOST)"; \
				$(SUDO) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- build --flake .#$(HOST) --impure; \
			elif [ -n "$(DETECTED_HOST)" ]; then \
				echo "Auto-detected host: $(DETECTED_HOST)"; \
				$(SUDO) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- build --flake .#$(DETECTED_HOST) --impure; \
			else \
				$(SUDO) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- build --flake .#$(NIX_SYSTEM) --impure; \
			fi; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			HOST=$(DETECTED_HOST) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage $(NIX_FLAGS) --impure --show-trace; \
		else \
			echo "Unsupported OS $(OS) for non-CI build"; \
			exit 1; \
		fi; \
	fi
	@echo "✅ Nix configuration built successfully!"

.PHONY: nix-daemon-update
nix-daemon-update: ## Upgrade Determinate Nix daemon to latest version.
	@if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
		echo "⏭️ Skipping determinate-nixd upgrade in CI"; \
	else \
		echo "⬆️ Upgrading Determinate Nix daemon..."; \
		$(SUDO) determinate-nixd upgrade || true; \
	fi

.PHONY: nix-flake-check
nix-flake-check: ## Check Nix flake configuration.
	@echo "🔍 Checking Nix flake configuration..."
	@if [ "$(OS)" = "Darwin" ]; then \
		$(NIX_ALLOW_UNFREE) $(NIX_EXEC) flake check --all-systems --impure $(NIX_FLAGS); \
	else \
		$(NIX_ALLOW_UNFREE) $(NIX_EXEC) flake check --system $(NIX_SYSTEM) --impure $(NIX_FLAGS); \
	fi
	@echo "✅ Nix flake check completed successfully"

.PHONY: nix-flake-update
nix-flake-update: nix-connect ## Update flake.lock file.
	@echo "♻️ Refreshing flake.lock file..."
	@if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ] || [ "$$AUTOMATED_UPDATE" = "true" ]; then \
		echo "Bypassing flake update in CI/Docker/automated update"; \
	else \
		$(NIX_EXEC) flake update $(NIX_FLAGS); \
	fi
	@echo "✅ flake.lock updated!"

.PHONY: nix-format
nix-format: nix-format-clear-cache ## Format Nix files.
	@echo "🧹 Formatting Nix files..."
	@$(NIX_EXEC) fmt -- --clear-cache
	@echo "✅ Formatting complete"

.PHONY: nix-format-clear-cache
nix-format-clear-cache: ## Clear Nix format cache.
	@echo "🧹 Clearing Nix cache..."
	@$(NIX_EXEC) fmt -- --clear-cache
	@echo "✅ Cache cleared"

.PHONY: nix-format-check
nix-format-check: ## Check Nix file formatting.
	@echo "🔍 Checking Nix file formatting..."
	@$(NIX_EXEC) fmt -- --clear-cache --fail-on-change
	@echo "✅ All Nix files are properly formatted"

.PHONY: nix-lint
nix-lint: ## Lint Nix files with statix from the flake/dev shell.
	@echo "🔍 Linting Nix files with statix..."
	@DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS) .# --command statix check .
	@echo "🔍 Checking for dead Nix code with deadnix..."
	@DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS) .# --command deadnix .
	@echo "✅ All Nix files pass lint checks"

.PHONY: nix-switch
nix-switch: ## Activate Nix configuration.
	@echo "🔧 Activating Nix configuration for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
		if [ "$(OS)" = "Darwin" ]; then \
			$(SUDO) env CI="$$CI" IN_DOCKER="$$IN_DOCKER" $(NIX_ALLOW_UNFREE) $(DARWIN_REBUILD) switch --flake .#runner --impure --no-update-lock-file; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			echo "⏭️ NixOS switch skipped in CI as the runner is not a NixOS system"; \
			$(SUDO) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure nixpkgs#nixos-rebuild -- switch --flake .#runner --no-update-lock-file || exit 0; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			if [ "$$SKIP_HOME_MANAGER_SWITCH" = "true" ]; then \
				echo "⏭️ Home-manager switch skipped (SKIP_HOME_MANAGER_SWITCH=true)"; \
			else \
				USER=$(NIX_USERNAME) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage; \
			fi; \
		else \
			echo "Unsupported OS $(OS) for non-CI switch"; \
			exit 1; \
		fi; \
	else \
		if [ "$(NIX_SYSTEM)" = "unsupported" ]; then \
			echo "❌ Unsupported system architecture: $(OS) $(ARCH)"; \
			exit 1; \
		elif [ "$(OS)" = "Darwin" ]; then \
			if [ -n "$(HOST)" ]; then \
				echo "Switching named host: $(HOST)"; \
				$(SUDO) HOST=$(HOST) $(NIX_ALLOW_UNFREE) $(DARWIN_REBUILD) switch --flake .#$(HOST) --impure; \
			elif [ -n "$(DETECTED_HOST)" ]; then \
				echo "Auto-detected host: $(DETECTED_HOST)"; \
				$(SUDO) HOST=$(DETECTED_HOST) $(NIX_ALLOW_UNFREE) $(DARWIN_REBUILD) switch --flake .#$(DETECTED_HOST) --impure; \
			else \
				$(SUDO) HOST=$(NIX_SYSTEM) $(NIX_ALLOW_UNFREE) $(DARWIN_REBUILD) switch --flake .#$(NIX_SYSTEM) --impure; \
			fi; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			if [ -n "$(HOST)" ]; then \
				echo "Switching named host: $(HOST)"; \
				$(SUDO) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- switch --flake .#$(HOST) --impure; \
			elif [ -n "$(DETECTED_HOST)" ]; then \
				echo "Auto-detected host: $(DETECTED_HOST)"; \
				$(SUDO) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- switch --flake .#$(DETECTED_HOST) --impure; \
			else \
				$(SUDO) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- switch --flake .#$(NIX_SYSTEM) --impure; \
			fi; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			if [ -n "$(HOST)" ]; then \
				echo "Switching named home config: $(HOST)"; \
				HOST=$(HOST) USER=$(NIX_USERNAME) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure .#homeConfigurations.$(HOST).activationPackage; \
			elif [ -n "$(DETECTED_HOST)" ]; then \
				echo "Auto-detected host: $(DETECTED_HOST)"; \
				HOST=$(DETECTED_HOST) USER=$(NIX_USERNAME) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure .#homeConfigurations.$(DETECTED_HOST).activationPackage; \
			else \
				USER=$(NIX_USERNAME) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage; \
			fi; \
		else \
			echo "Unsupported OS $(OS) for non-CI switch"; \
			exit 1; \
		fi; \
	fi
	@echo "✅ Nix configuration activated successfully!"

.PHONY: nix-switch-vm
nix-switch-vm: ## Switch NixOS configuration in VM.
	@if [ ! -f "./result/bin/run-nixos-vm" ]; then \
		echo "❌ VM binary not found at ./result/bin/run-nixos-vm"; \
		exit 0; \
	fi; \
	export QEMU_OPTS="-m 4096 -smp 2"; \
	printf "sleep 5\nmkdir -p /tmp/test && cd /tmp/test\ncp -r /mnt/shared/* .\n$(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- switch --flake .#runner --no-update-lock-file\npoweroff\n" > vm_commands.txt; \
	timeout 600 ./result/bin/run-nixos-vm -nographic < vm_commands.txt || exit 1; \
	rm -f vm_commands.txt

##@ Nix Offline Mode

.PHONY: nix-build-offline 
nix-build-offline: ## Build Nix configuration in offline mode.
	@echo "🏗️ Building Nix configuration in offline mode"
	@if [ "$(OS)" = "Darwin" ]; then \
		NIX_OFFLINE=1 $(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#darwinConfigurations.galactica.system $(NIX_FLAGS) --impure --no-update-lock-file --offline --show-trace; \
	elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
		NIX_OFFLINE=1 $(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#nixosConfigurations.runner.config.system.build.toplevel $(NIX_FLAGS) --impure --no-update-lock-file --offline --show-trace; \
	elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
		NIX_OFFLINE=1 $(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage $(NIX_FLAGS) --impure --no-update-lock-file --offline --show-trace; \
	else \
		echo "Unsupported OS $(OS) for offline build"; \
		exit 1; \
	fi
	@echo "✅ Nix configuration built successfully in offline mode!"

.PHONY: nix-switch-offline
nix-switch-offline: ## Activate Nix configuration in offline mode.
	@echo "🔧 Activating Nix configuration in offline mode"
	@if [ "$(OS)" = "Darwin" ]; then \
		NIX_OFFLINE=1 $(SUDO) $(NIX_ALLOW_UNFREE) $(DARWIN_REBUILD) switch --flake .#galactica --impure --offline; \
	elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
		NIX_OFFLINE=1 $(SUDO) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure nixpkgs#nixos-rebuild -- switch --flake .#runner --no-update-lock-file --offline || exit 0; \
	elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
		NIX_OFFLINE=1 USER=$(NIX_USERNAME) $(SUDO) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage --offline; \
	else \
		echo "Unsupported OS $(OS) for offline switch"; \
		exit 1; \
	fi
	@echo "✅ Nix configuration activated successfully in offline mode!"

.PHONY: nix-setup-offline
nix-setup-offline: ## Set up offline environment.
	@echo "🔧 Setting up offline environment"
	@mkdir -p ~/.cache/nix
	@echo "✅ Offline environment setup complete"

##@ Offline Mode

##@ Named Hosts Specific Targets

.PHONY: switch-%
switch-%: ## Switch to a named host configuration (e.g., make switch-galactica).
	@$(MAKE) nix-switch HOST=$*

.PHONY: encrypt-key-%
encrypt-key-%: ## Encrypt a key for a named host (e.g., make encrypt-key-galactica KEY_FILE=~/.ssh/id_ed25519).
	@$(MAKE) encrypt-key HOST=$* KEY_FILE=$(KEY_FILE)

.PHONY: decrypt-key-%
decrypt-key-%: ## Decrypt a key for a named host (e.g., make decrypt-key-galactica KEY_FILE=id_ed25519).
	@$(MAKE) decrypt-key HOST=$* KEY_FILE=$(KEY_FILE)

.PHONY: rekey-%
rekey-%: ## Rekey all secrets for a named host (e.g., make rekey-galactica).
	@$(MAKE) rekey HOST=$*

##@ Agenix Secrets Management

.PHONY: encrypt-key
encrypt-key: ## Encrypt a key file for a host (requires HOST and KEY_FILE variables).
	@if [ -z "$(HOST)" ]; then \
		echo "❌ HOST variable is not set. Usage: make encrypt-key HOST=<hostname> KEY_FILE=<path_to_key>"; \
		exit 1; \
	fi
	@if [ -z "$(KEY_FILE)" ]; then \
		echo "❌ KEY_FILE variable is not set. Usage: make encrypt-key HOST=<hostname> KEY_FILE=<path_to_key>"; \
		exit 1; \
	fi
	@echo "🔐 Encrypting $(KEY_FILE) for host $(HOST)..."
	@cd named-hosts/$(HOST) && mkdir -p keys && cat $(KEY_FILE) | agenix -e keys/$(shell basename $(KEY_FILE)).age
	@echo "✅ Key encrypted to named-hosts/$(HOST)/keys/$(shell basename $(KEY_FILE)).age"

.PHONY: decrypt-key
decrypt-key: ## Decrypt a key file for a host (requires HOST variable, optional KEY_FILE).
	@if [ -z "$(HOST)" ]; then \
		echo "❌ HOST variable is not set. Usage: make decrypt-key HOST=<hostname> KEY_FILE=<path_to_key>"; \
		exit 1; \
	fi
	@if [ -z "$(KEY_FILE)" ]; then \
		KEY_FILE="id_ed25519"; \
	fi
	@echo "🔓 Decrypting keys/$(KEY_FILE).age for host $(HOST)..."
	@cd named-hosts/$(HOST) && agenix -d keys/$(KEY_FILE).age

.PHONY: rekey
rekey: ## Rekey all secrets for a host (requires HOST variable).
	@if [ -z "$(HOST)" ]; then \
		echo "❌ HOST variable is not set. Usage: make rekey HOST=<hostname>"; \
		exit 1; \
	fi
	@echo "🔑 Rekeying all secrets for host $(HOST)..."
	@cd named-hosts/$(HOST) && agenix --rekey
	@echo "✅ Rekeying complete for $(HOST)."

##@ Shell Installation

.PHONY: shell-install
shell-install: ## Set up Fish shell as default shell.
	@echo "🐠 Setting up Fish shell..."
	@if command -v fish > /dev/null; then \
		fish_path=$$(command -v fish); \
		if ! grep -q "$$fish_path" /etc/shells; then \
			echo "Adding $$fish_path to /etc/shells..."; \
			echo $$fish_path | $(SUDO) tee -a /etc/shells; \
		fi; \
		if [ "$$(basename "$$SHELL")" != "fish" ]; then \
			echo "Changing default shell to Fish shell..."; \
			chsh -s $$fish_path; \
			echo "✅ Default shell changed to Fish. Please log out and back in for changes to take effect."; \
		else \
			echo "✅ Fish is already the default shell."; \
		fi; \
	else \
		echo "⚠️ Fish shell not found. Skipping Fish setup."; \
	fi


##@ Docker

.PHONY: docker-build
docker-build: ## Build Docker image.
	@echo "🐳 Building Docker image: $(DOCKER_IMAGE_LATEST) and $(DOCKER_IMAGE_TAGGED)..."
	@docker build -t $(DOCKER_IMAGE_LATEST) -t $(DOCKER_IMAGE_TAGGED) -f Dockerfile .
	@echo "✅ Docker image built: $(DOCKER_IMAGE_LATEST) and $(DOCKER_IMAGE_TAGGED)"

##@ Neovim

.PHONY: neovim-dev
neovim-dev: ## Set up local Neovim development environment.
	@echo "🔧 Setting up local Neovim development environment..."
	@if [ -L "$(HOME)/.config/nvim" ]; then \
		rm "$(HOME)/.config/nvim"; \
	fi
	@mkdir -p "$(HOME)/.config/nvim"
	@if [ -L "$(HOME)/.config/nvim/lua" ] || [ -d "$(HOME)/.config/nvim/lua" ]; then \
		rm -rf "$(HOME)/.config/nvim/lua"; \
	fi
	@ln -sf "$(PWD)/home-manager/programs/neovim/init.lua" "$(HOME)/.config/nvim/init.lua"
	@ln -sf "$(PWD)/home-manager/programs/neovim/lua" "$(HOME)/.config/nvim/lua"
	@ln -sf "$(PWD)/home-manager/programs/neovim/nvim-pack-lock.json" "$(HOME)/.config/nvim/nvim-pack-lock.json"
	@echo "✅ Local Neovim development environment ready"
	@echo "🚧 To restore the Nix-managed version, run 'make switch'"

.PHONY: neovim-sync
neovim-sync: neovim-update ## Sync Neovim plugins.
	@echo "🔄 Syncing neovim plugins..."
	@nvim --headless +"lua vim.cmd('source ' .. vim.fn.stdpath('config') .. '/init.lua')" +qa
	@echo "✅ Neovim plugins synced"

.PHONY: neovim-update
neovim-update: ## Update Neovim plugins.
	@echo "📦 Updating neovim plugins..."
	@mkdir -p ~/.config/nvim
	@if [ -L "$(HOME)/.config/nvim/lua" ] || [ -d "$(HOME)/.config/nvim/lua" ]; then \
		rm -rf "$(HOME)/.config/nvim/lua"; \
	fi
	@ln -sf "$(PWD)/home-manager/programs/neovim/init.lua" ~/.config/nvim/init.lua
	@ln -sf "$(PWD)/home-manager/programs/neovim/lua" ~/.config/nvim/lua
	@ln -sf "$(PWD)/home-manager/programs/neovim/nvim-pack-lock.json" ~/.config/nvim/nvim-pack-lock.json
	@nvim --headless +"lua vim.pack.update()" +qa
	@echo "✅ Neovim plugins updated"

.PHONY: neovim-test
neovim-test: ## Run Neovim tests using plenary.nvim.
	@echo "🧪 Running Neovim tests..."
	@$(PWD)/home-manager/programs/neovim/run_tests.sh
	@echo "✅ Neovim tests completed"

.PHONY: neovim-test-dev
neovim-test-dev: ## Run Neovim tests inside the Nix dev shell (mirrors CI).
	@echo "🧪 Running Neovim tests inside the Nix dev shell..."
	@DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS) .# --command $(MAKE) neovim-test

##@ Lua

.PHONY: lua-check
lua-check: lua-check-neovim lua-check-hammerspoon ## Check all Lua configurations (Neovim and Hammerspoon).
	@echo "✅ All Lua configurations validated"

.PHONY: lua-check-neovim
lua-check-neovim: ## Check Neovim configuration.
	@echo "🔍 Checking Neovim configuration..."
	@if ! command -v nvim >/dev/null 2>&1; then \
		echo "⚠️  Neovim is not installed or not in PATH"; \
		exit 1; \
	fi
	@NVIM_CONFIG="$(PWD)/home-manager/programs/neovim/init.lua"; \
	if [ ! -f "$$NVIM_CONFIG" ]; then \
		echo "⚠️  Could not find Neovim configuration at $$NVIM_CONFIG"; \
		exit 1; \
	fi
	@echo "📝 Validating Neovim configuration syntax..."
	@echo "📦 Installing plugins..."
	@nvim -u "$(PWD)/home-manager/programs/neovim/init.lua" --headless +"lua vim.pack.update()" +qa 2>&1
	@bash $(PWD)/scripts/build-neovim-plugins.sh
	@nvim -u "$(PWD)/home-manager/programs/neovim/init.lua" --headless -c "qa" 2>&1 | tee /tmp/nvim-check.log; \
	if grep -q "^E[0-9]\|^Error\|module .* not found" /tmp/nvim-check.log; then \
		echo "❌ Neovim configuration has errors"; \
		exit 1; \
	fi
	@echo "✅ Neovim configuration is valid"

.PHONY: lua-check-neovim-dev
lua-check-neovim-dev: ## Run the Neovim Lua check inside the Nix dev shell (mirrors CI).
	@echo "🧪 Running Neovim Lua check inside the Nix dev shell..."
	@DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS) .# --command $(MAKE) lua-check-neovim

.PHONY: lua-check-hammerspoon
lua-check-hammerspoon: ## Check Hammerspoon configuration.
	@echo "🔍 Checking Hammerspoon configuration..."
	@HAMMERSPOON_CONFIG="$(PWD)/config/hammerspoon/init.lua"; \
	if [ ! -f "$$HAMMERSPOON_CONFIG" ]; then \
		echo "⚠️  Could not find Hammerspoon configuration at $$HAMMERSPOON_CONFIG"; \
		exit 1; \
	fi
	@echo "📝 Validating Hammerspoon configuration syntax..."
	@if command -v lua >/dev/null 2>&1; then \
		lua -e "assert(loadfile('$(PWD)/config/hammerspoon/init.lua'))" && \
		echo "✅ Hammerspoon configuration is valid" || \
		(echo "❌ Hammerspoon configuration has syntax errors" && exit 1); \
	elif command -v nix >/dev/null 2>&1; then \
		nix run nixpkgs#lua -- -e "assert(loadfile('$(PWD)/config/hammerspoon/init.lua'))" && \
		echo "✅ Hammerspoon configuration is valid" || \
		(echo "❌ Hammerspoon configuration has syntax errors" && exit 1); \
	else \
		echo "⚠️  Neither lua nor nix is available for syntax checking"; \
		exit 1; \
	fi

.PHONY: lua-check-hammerspoon-dev
lua-check-hammerspoon-dev: ## Run the Hammerspoon Lua check inside the Nix dev shell (mirrors CI).
	@echo "🧪 Running Hammerspoon Lua check inside the Nix dev shell..."
	@DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS) .# --command $(MAKE) lua-check-hammerspoon

##@ Launchd Services

.PHONY: launchctl
launchctl: launchctl-brew-upgrader launchctl-openclaw launchctl-cliproxyapi launchctl-cliproxyapi-backup launchctl-code-syncer launchctl-docker-postgres launchctl-dotfiles-updater launchctl-neverssl-keepalive launchctl-ollama launchctl-tmux-session-logger ## Restart all launchd agents.

.PHONY: launchctl-brew-upgrader
launchctl-brew-upgrader: ## Restart brew-updater launchd agent.
	@echo "🔄 Restarting brew-updater..."
	@launchctl unload ~/Library/LaunchAgents/org.nix-community.home.brew-updater.plist 2>/dev/null || true
	@sleep 3
	@launchctl load ~/Library/LaunchAgents/org.nix-community.home.brew-updater.plist
	@echo "✅ brew-updater restarted"

.PHONY: launchctl-cliproxyapi
launchctl-cliproxyapi: ## Restart cliproxyapi launchd agent.
	@echo "🔄 Restarting cliproxyapi..."
	@launchctl unload ~/Library/LaunchAgents/org.nix-community.home.cliproxyapi.plist 2>/dev/null || true
	@sleep 3
	@launchctl load ~/Library/LaunchAgents/org.nix-community.home.cliproxyapi.plist
	@echo "✅ cliproxyapi restarted"

.PHONY: launchctl-cliproxyapi-backup
launchctl-cliproxyapi-backup: ## Restart cliproxyapi backup launchd agent.
	@echo "🔄 Restarting cliproxyapi-backup..."
	@launchctl unload ~/Library/LaunchAgents/org.nix-community.home.cliproxyapi-backup.plist 2>/dev/null || true
	@sleep 3
	@launchctl load ~/Library/LaunchAgents/org.nix-community.home.cliproxyapi-backup.plist
	@echo "✅ cliproxyapi-backup restarted"

.PHONY: launchctl-code-syncer
launchctl-code-syncer: ## Restart code-syncer launchd agent.
	@echo "🔄 Restarting code-syncer..."
	@launchctl unload ~/Library/LaunchAgents/org.nix-community.home.code-syncer.plist 2>/dev/null || true
	@sleep 3
	@launchctl load ~/Library/LaunchAgents/org.nix-community.home.code-syncer.plist
	@echo "✅ code-syncer restarted"

.PHONY: launchctl-dotfiles-updater
launchctl-dotfiles-updater: ## Restart dotfiles-updater launchd agent.
	@echo "🔄 Restarting dotfiles-updater..."
	@launchctl unload ~/Library/LaunchAgents/org.nix-community.home.dotfiles-updater.plist 2>/dev/null || true
	@sleep 3
	@launchctl load ~/Library/LaunchAgents/org.nix-community.home.dotfiles-updater.plist
	@echo "✅ dotfiles-updater restarted"

.PHONY: launchctl-openclaw
launchctl-openclaw: ## Restart OpenClaw gateway launchd agent.
	@echo "🔄 Restarting openclaw..."
	@launchctl unload ~/Library/LaunchAgents/bot.molt.gateway.plist 2>/dev/null || true
	@sleep 3
	@launchctl load ~/Library/LaunchAgents/bot.molt.gateway.plist
	@echo "✅ openclaw restarted"

.PHONY: launchctl-neverssl-keepalive
launchctl-neverssl-keepalive: ## Restart neverssl-keepalive launchd agent.
	@echo "🔄 Restarting neverssl-keepalive..."
	@launchctl unload ~/Library/LaunchAgents/org.nix-community.home.neverssl-keepalive.plist 2>/dev/null || true
	@sleep 3
	@launchctl load ~/Library/LaunchAgents/org.nix-community.home.neverssl-keepalive.plist
	@echo "✅ neverssl-keepalive restarted"

.PHONY: launchctl-docker-postgres
launchctl-docker-postgres: ## Restart docker-postgres launchd agent.
	@echo "🔄 Restarting docker-postgres..."
	@launchctl unload ~/Library/LaunchAgents/org.nix-community.home.docker-postgres.plist 2>/dev/null || true
	@sleep 3
	@launchctl load ~/Library/LaunchAgents/org.nix-community.home.docker-postgres.plist
	@echo "✅ docker-postgres restarted"

.PHONY: launchctl-ollama
launchctl-ollama: ## Restart ollama launchd agent.
	@echo "🔄 Restarting ollama..."
	@launchctl unload ~/Library/LaunchAgents/org.nix-community.home.ollama.plist 2>/dev/null || true
	@sleep 3
	@launchctl load ~/Library/LaunchAgents/org.nix-community.home.ollama.plist
	@echo "✅ ollama restarted"

.PHONY: launchctl-tmux-session-logger
launchctl-tmux-session-logger: ## Restart tmux-session-logger launchd agent.
	@echo "🔄 Restarting tmux-session-logger..."
	@launchctl unload ~/Library/LaunchAgents/org.nix-community.home.tmux-session-logger.plist 2>/dev/null || true
	@sleep 3
	@launchctl load ~/Library/LaunchAgents/org.nix-community.home.tmux-session-logger.plist
	@echo "✅ tmux-session-logger restarted"

##@ Systemd Services (Linux)

.PHONY: systemctl
systemctl: systemctl-cliproxyapi systemctl-cliproxyapi-backup systemctl-code-syncer systemctl-docker-postgres systemctl-dotfiles-updater systemctl-make-updater systemctl-neverssl-keepalive systemctl-obsidian systemctl-ollama systemctl-openclaw systemctl-paperclip systemctl-tmux-session-logger ## Restart all systemd user services.

.PHONY: systemctl-cliproxyapi
systemctl-cliproxyapi: ## Restart cliproxyapi systemd user service.
	@echo "🔄 Restarting cliproxyapi..."
	@systemctl --user daemon-reload
	@systemctl --user restart cliproxyapi.service || true
	@echo "✅ cliproxyapi restarted"

.PHONY: systemctl-cliproxyapi-backup
systemctl-cliproxyapi-backup: ## Restart cliproxyapi-backup systemd user service.
	@echo "🔄 Restarting cliproxyapi-backup..."
	@systemctl --user restart cliproxyapi-backup.service || true
	@echo "✅ cliproxyapi-backup restarted"

.PHONY: systemctl-code-syncer
systemctl-code-syncer: ## Restart code-syncer systemd user service.
	@echo "🔄 Restarting code-syncer..."
	@systemctl --user restart code-syncer.service || true
	@echo "✅ code-syncer restarted"

.PHONY: systemctl-docker-postgres
systemctl-docker-postgres: ## Restart docker-postgres systemd user service.
	@echo "🔄 Restarting docker-postgres..."
	@systemctl --user restart docker-postgres.service || true
	@echo "✅ docker-postgres restarted"

.PHONY: systemctl-dotfiles-updater
systemctl-dotfiles-updater: ## Restart dotfiles-updater systemd user service.
	@echo "🔄 Restarting dotfiles-updater..."
	@systemctl --user restart dotfiles-updater.service || true
	@echo "✅ dotfiles-updater restarted"

.PHONY: systemctl-make-updater
systemctl-make-updater: ## Restart make-updater systemd timer and service.
	@echo "🔄 Restarting make-updater..."
	@systemctl --user restart make-updater.timer || true
	@echo "✅ make-updater restarted"

.PHONY: systemctl-neverssl-keepalive
systemctl-neverssl-keepalive: ## Restart neverssl-keepalive systemd timer and service.
	@echo "🔄 Restarting neverssl-keepalive..."
	@systemctl --user restart neverssl-keepalive.timer || true
	@echo "✅ neverssl-keepalive restarted"

.PHONY: systemctl-obsidian
systemctl-obsidian: ## Restart Obsidian headless systemd user service.
	@echo "🔄 Restarting obsidian..."
	@if [ "$(DETECTED_HOST)" = "kyber" ] || [ "$(HOST)" = "kyber" ]; then \
		systemctl --user daemon-reload; \
		systemctl --user restart obsidian.service; \
	else \
		echo "Skipping obsidian.service (host not kyber)"; \
	fi
	@echo "✅ obsidian restarted"

.PHONY: systemctl-ollama
systemctl-ollama: ## Restart ollama systemd user service.
	@echo "🔄 Restarting ollama..."
	@systemctl --user restart ollama.service || true
	@echo "✅ ollama restarted"

.PHONY: systemctl-openclaw
systemctl-openclaw: ## Restart OpenClaw gateway systemd user service.
	@echo "🔄 Restarting openclaw..."
	@if [ "$(DETECTED_HOST)" = "kyber" ] || [ "$(HOST)" = "kyber" ]; then \
		systemctl --user restart openclaw-gateway.service; \
	else \
		echo "Skipping openclaw-gateway.service (host not kyber)"; \
	fi
	@echo "✅ openclaw restarted"

.PHONY: systemctl-paperclip
systemctl-paperclip: ## Restart Paperclip systemd user service.
	@echo "🔄 Restarting paperclip..."
	@if [ "$(DETECTED_HOST)" = "kyber" ] || [ "$(HOST)" = "kyber" ]; then \
		systemctl --user daemon-reload; \
		systemctl --user restart paperclip.service; \
	else \
		echo "Skipping paperclip.service (host not kyber)"; \
	fi
	@echo "✅ paperclip restarted"

.PHONY: systemctl-tmux-session-logger
systemctl-tmux-session-logger: ## Restart tmux-session-logger systemd timer and service.
	@echo "🔄 Restarting tmux-session-logger..."
	@systemctl --user restart tmux-session-logger.timer || true
	@echo "✅ tmux-session-logger restarted"

.PHONY: git-submodule-sync
git-submodule-sync: ## Sync and update git submodules.
	@echo "🔁 Syncing and updating git submodules..."
	@git submodule sync
	@git submodule update --init --recursive
	@echo "✅ Submodules synced and updated"

##@ Shell

.PHONY: shell-test
shell-test: ## Run shell script tests using ShellSpec and fishtape.
	@echo "🧪 Running shell tests..."
	@bash -c "shellspec"
	@$(MAKE) fish-test

.PHONY: shell-test-dev
shell-test-dev: ## Run shell tests inside the Nix dev shell (mirrors CI).
	@echo "🧪 Running shell tests inside the Nix dev shell..."
	@DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS) .# --command $(MAKE) shell-test

.PHONY: fish-test
fish-test: ## Run fish function tests using fishtape.
	@echo "🐟 Running fish function tests..."
	@fish_runner=$$(command -v fishtape 2>/dev/null || true); \
	if [ -z "$$fish_runner" ]; then \
	  set -- /nix/store/*-fishtape/bin/fishtape; \
	  if [ -x "$$1" ]; then \
	    fish_runner=$$1; \
	    echo "  fishtape not on PATH, using $$fish_runner"; \
	  else \
	    echo "  fishtape not found, running inside Nix dev shell..."; \
	    $(MAKE) fish-test-dev; \
	    exit $$?; \
	  fi; \
	fi; \
	fish_home=$$(mktemp -d "$${TMPDIR:-/tmp}/fish-test.XXXXXX"); \
	fish_errors=$$(mktemp); \
	fish_errors_filtered=$$(mktemp); \
	trap 'rm -rf "$$fish_home" "$$fish_errors" "$$fish_errors_filtered"' EXIT; \
	mkdir -p "$$fish_home/.config/fish" "$$fish_home/.local/state" "$$fish_home/.local/share"; \
	HOME="$$fish_home" \
	XDG_CONFIG_HOME="$$fish_home/.config" \
	XDG_STATE_HOME="$$fish_home/.local/state" \
	XDG_DATA_HOME="$$fish_home/.local/share" \
	"$$fish_runner" spec/fish/*_test.fish 2>"$$fish_errors"; \
	rc=$$?; \
	grep -v -E '^(warning: notify_register_file_descriptor\(\) failed with status 9\.|warning: Universal variable notifications may not be received\.)$$' "$$fish_errors" >"$$fish_errors_filtered" || true; \
	if [ -s "$$fish_errors_filtered" ]; then \
	  echo "fish test stderr (failing):"; cat "$$fish_errors_filtered"; exit 1; \
	fi; \
	exit $$rc

.PHONY: fish-test-dev
fish-test-dev: ## Run fish tests inside the Nix dev shell (mirrors CI).
	@echo "🐟 Running fish function tests inside the Nix dev shell..."
	@DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS) .# --command $(MAKE) fish-test

.PHONY: shell-check
shell-check: ## Run ShellCheck on shell scripts.
	@echo "🔍 Running ShellCheck..."
	@find . -name '*.sh' -not -path './node_modules/*' -not -path './.git/*' -not -path './.worktrees/*' -not -path './result/*' -not -path './.venv/*' -not -path './.claude/*' -not -path './dotagents/.claude/*' -not -path './dotagents/.codex/*' -print0 | xargs -0 shellcheck

.PHONY: shell-check-dev
shell-check-dev: ## Run ShellCheck inside the Nix dev shell (mirrors CI).
	@echo "🔍 Running ShellCheck inside the Nix dev shell..."
	@DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS) .# --command $(MAKE) shell-check

.PHONY: shell-lint
shell-lint: shell-check ## Lint shell scripts (alias for shell-check).

.PHONY: shell-inline-check
shell-inline-check: ## Fail if any .nix file contains inline shell or Python write*Script* strings.
	@echo "🔍 Checking for inline scripts in Nix files..."
	@bash scripts/check-nix-inline-scripts.sh

##@ Python

.PHONY: python-test
python-test: ## Run Python tests with pytest.
	@echo "🧪 Running Python tests..."
	@uv run --with pytest --no-project pytest tests

.PHONY: python-test-dev
python-test-dev: ## Run Python tests inside the Nix dev shell (mirrors CI).
	@echo "🧪 Running Python tests inside the Nix dev shell..."
	@DEVENV_ROOT=$(CURDIR) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS) .# --command $(MAKE) python-test

.PHONY: python-lint
python-lint: ## Lint Python files with Ruff.
	@echo "🔍 Linting Python files with Ruff..."
	@uv run --with ruff --no-project ruff check
	@uv run --with ruff --no-project ruff format --check --diff

##@ Nix Tests

.PHONY: nix-test
nix-test: ## Run Nix flake checks (eval, overlay, lib tests).
	@echo "🧪 Running Nix tests via flake checks..."
	@$(NIX_ALLOW_UNFREE) $(NIX_EXEC) flake check --system $(NIX_SYSTEM) --impure $(NIX_FLAGS) --print-build-logs
	@echo "✅ Nix tests passed"

##@ Doppler

.PHONY: doppler-sync
doppler-sync: ## Sync Doppler secrets (dotfiles/prd) to .env file.
	@echo "🔐 Syncing Doppler secrets to .env..."
	@doppler secrets download --project dotfiles --config prd --format env --no-file > .env
	@echo "✅ .env file updated from Doppler (dotfiles/prd)"

.PHONY: doppler-upload
doppler-upload: ## Upload .env file to Doppler (dotfiles/prd).
	@echo "🔐 Uploading .env to Doppler..."
	@doppler secrets upload --project dotfiles --config prd .env
	@echo "✅ .env uploaded to Doppler (dotfiles/prd)"

##@ Gas Town

.PHONY: gt-remote-setup
gt-remote-setup: ## Bootstrap Gas Town on a remote server (init town, add rig, start services).
	@echo "🏭 Bootstrapping Gas Town on remote..."
	@./scripts/gt-remote-bootstrap.sh
	@echo "✅ Gas Town bootstrapped"

.PHONY: gt-sync
gt-sync: ## Push local Dolt databases to configured DoltHub remotes.
	@echo "🔄 Syncing Dolt databases to remotes..."
	@gt dolt sync
	@echo "✅ Dolt databases synced"

.PHONY: gt-pull
gt-pull: ## Pull Dolt databases from configured remotes.
	@echo "🔄 Pulling Dolt databases from remotes..."
	@gt dolt pull
	@echo "✅ Dolt databases pulled"

.PHONY: gt-status
gt-status: ## Show Gas Town health and Dolt server status.
	@gt health

.PHONY: gt-dolt-status
gt-dolt-status: ## Show Dolt server status and latency.
	@gt dolt status

