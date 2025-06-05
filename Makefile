##@ Variables

# Detect architecture and OS
ARCH := $(shell uname -m)
OS := $(shell uname -s)

# Git variables
GIT_REMOTE_ORIGIN_URL := $(shell git config --get remote.origin.url)
GITHUB_REPO_PATH := $(shell echo $(GIT_REMOTE_ORIGIN_URL) | sed -n 's/.*github.com[:/]\(.*\)\.git/\1/p')
GITHUB_REPO_OWNER := $(shell echo $(GITHUB_REPO_PATH) | cut -d'/' -f1)
GITHUB_REPO_NAME := $(shell echo $(GITHUB_REPO_PATH) | cut -d'/' -f2)
GIT_COMMIT_SHA := $(shell git rev-parse --short HEAD)

# Docker image names
DOCKER_IMAGE_NAME_BASE := ghcr.io/$(GITHUB_REPO_OWNER)/$(GITHUB_REPO_NAME)
DOCKER_IMAGE_LATEST := $(DOCKER_IMAGE_NAME_BASE):latest
DOCKER_IMAGE_TAGGED := $(DOCKER_IMAGE_NAME_BASE):$(GIT_COMMIT_SHA)

# Nix executable path
NIX_EXEC := $(shell \
	path_to_nix=""; \
	if [ "$(OS)" = "Darwin" ]; then \
		if [ -x "/nix/var/nix/profiles/default/bin/nix" ]; then \
			path_to_nix="/nix/var/nix/profiles/default/bin/nix"; \
		elif command -v nix 2>/dev/null; then \
			path_to_nix=$$(command -v nix); \
		else \
			path_to_nix="nix"; \
		fi; \
	elif [ "$(OS)" = "Linux" ]; then \
		if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
			if [ -x "$${HOME}/.nix-profile/bin/nix" ]; then \
				path_to_nix="$${HOME}/.nix-profile/bin/nix"; \
			elif command -v nix 2>/dev/null; then \
				path_to_nix=$$(command -v nix); \
			else \
				path_to_nix="nix"; \
			fi; \
		else \
			if [ -x "$${HOME}/.nix-profile/bin/nix" ]; then \
				path_to_nix="$${HOME}/.nix-profile/bin/nix"; \
			elif command -v nix 2>/dev/null; then \
				path_to_nix=$$(command -v nix); \
			else \
				path_to_nix=$$(command -v nix 2>/dev/null || echo "nix"); \
			fi; \
		fi; \
	else \
		if command -v nix 2>/dev/null; then \
			path_to_nix=$$(command -v nix); \
		else \
			path_to_nix=$$(command -v nix 2>/dev/null || echo "nix"); \
		fi; \
	fi; \
	echo "$$path_to_nix")

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
	@echo "  docker-build - Build the Docker image"

##@ General

.PHONY: install
install: setup update shell-install

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
update: nix-update shell-update

##@ Nix Setup

.PHONY: nix-setup
nix-setup: nix-install nix-check nix-connect 

.PHONY: nix-connect
nix-connect:
	@echo "🔌 Ensuring Nix daemon is running for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@if [ "$(OS)" = "Darwin" ]; then \
		sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist 2>/dev/null || true; \
		sudo launchctl load -w /Library/LaunchDaemons/org.nixos.nix-daemon.plist; \
	elif [ "$(OS)" = "Linux" ]; then \
		if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
			echo "🏃‍♂️ Nix daemon management (e.g., systemctl) is skipped in CI/Docker environments."; \
			if [ "$$IN_DOCKER" = "true" ]; then \
				echo "ℹ️ Docker environment is using a single-user Nix installation (no separate daemon)."; \
			fi; \
		else \
			if [ -d /run/systemd/system ] && [ -S /run/systemd/private ]; then \
				echo "🐧 systemd detected as PID 1. Attempting to restart nix-daemon.service..."; \
				sudo systemctl restart nix-daemon.service; \
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

.PHONY: nix-check
nix-check:
	@echo "🔍 Verifying Nix environment setup for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "❌ Nix environment not found. Please ensure Nix is installed and run:"; \
		exit 1; \
	fi
	@echo "✅ Nix environment found!"

.PHONY: nix-install
nix-install:
	@echo "NIX_ENV current value: $(NIX_ENV)" # Debugging
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "🚀 Attempting to install Nix..."; \
		# Using a subshell with pipefail to ensure the pipeline's success is checked
		# Pass --no-daemon for typical single-user installs in ephemeral environments like Docker
		if (set -o pipefail; curl -fSL https://nixos.org/nix/install | sh -s -- --no-daemon); then \
			echo "✅ Nix installation script executed successfully."; \
			echo "Attempting to source Nix profile to update PATH for this session..."; \
			if [ -f "$${HOME}/.nix-profile/etc/profile.d/nix.sh" ]; then \
				. "$${HOME}/.nix-profile/etc/profile.d/nix.sh"; \
				echo "Nix profile sourced."; \
				# Update NIX_ENV Makefile variable for the current make execution if possible
				$(eval NIX_ENV := $(shell . $${HOME}/.nix-profile/etc/profile.d/nix.sh 2>/dev/null && echo "found" || echo "not_found")) \
				echo "NIX_ENV re-evaluated to: $(NIX_ENV)"; \
			else \
				echo "⚠️ Nix profile script not found at $${HOME}/.nix-profile/etc/profile.d/nix.sh after install attempt."; \
			fi; \
			# Verify Nix installation by checking for the command
			if command -v nix >/dev/null 2>&1; then \
				echo "✅ Nix command is now available in PATH."; \
			else \
				echo "❌ ERROR: Nix installation script ran, but 'nix' command is not available in PATH."; \
				echo "Current NIX_EXEC is: '$(NIX_EXEC)'"; \
				echo "Current PATH: $$PATH"; \
				exit 1; \
			fi; \
		else \
			echo "❌ ERROR: Nix installation script failed (curl or sh error). Exit code: $$?"; \
			exit 1; \
		fi; \
	else \
		echo "✅ Nix environment previously detected (NIX_ENV='$(NIX_ENV)'). Skipping installation."; \
	fi

##@ Nix

.PHONY: nix-update
nix-update: nix-build nix-switch

.PHONY: nix-backup
nix-backup:
	@echo "🗄️ Backing up configuration files for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@backup_dir="$$HOME/.config/backups/$(shell date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$backup_dir"; \
	if [ -d "$$HOME/.config" ]; then \
		cp -R "$$HOME/.config" "$$backup_dir/" 2>/dev/null || true; \
		echo "✅ Backup created at $$backup_dir"; \
	fi

.PHONY: nix-build
nix-build: nix-connect
	@echo "🏗️ Building Nix configuration for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
		echo "Running in CI"; \
		if [ "$(OS)" = "Darwin" ]; then \
			$(NIX_EXEC) build .#$(NIX_CONFIG_TYPE).runner.system $(NIX_FLAGS) --no-update-lock-file --show-trace; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			$(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- build --flake .#runner --no-update-lock-file; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			$(NIX_EXEC) build .#$(NIX_CONFIG_TYPE)."runner@$(NIX_SYSTEM)".activationPackage $(NIX_FLAGS) --no-update-lock-file --show-trace; \
		else \
			echo "Unsupported OS $(OS) for non-CI build"; \
			exit 1; \
		fi; \
	else \
		if [ "$(NIX_SYSTEM)" = "unsupported" ]; then \
			echo "❌ Unsupported system architecture: $(OS) $(ARCH)"; \
			exit 1; \
		elif [ "$(OS)" = "Darwin" ]; then \
			$(NIX_EXEC) build .#$(NIX_CONFIG_TYPE).$(NIX_SYSTEM).system $(NIX_FLAGS) --show-trace; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			sudo $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- build --flake .#$(NIX_SYSTEM); \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			$(NIX_EXEC) build .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage $(NIX_FLAGS) --show-trace; \
		else \
			echo "Unsupported OS $(OS) for non-CI build"; \
			exit 1; \
		fi; \
	fi
	@echo "✅ Nix configuration built successfully!"

.PHONY: nix-flake-update
nix-flake-update: nix-connect
	@echo "♻️ Refreshing flake.lock file..."
	@if [ "$$CI" = "true" ]; then \
		echo "Bypassing flake update in CI"; \
	else \
		$(NIX_EXEC) flake update $(NIX_FLAGS); \
	fi
	@echo "✅ flake.lock updated!"

.PHONY: nix-format
nix-format:
	@echo "🧹 Formatting Nix files..."
	@$(NIX_EXEC) fmt
	@echo "✅ Formatting complete"

.PHONY: nix-format-check
nix-format-check:
	@echo "🔍 Checking Nix file formatting..."
	@$(NIX_EXEC) fmt -- --fail-on-change
	@echo "✅ All Nix files are properly formatted"

.PHONY: nix-switch
nix-switch:
	@echo "🔧 Activating Nix configuration for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
		if [ "$(OS)" = "Darwin" ]; then \
			sudo $(DARWIN_REBUILD) switch --flake .#runner --no-update-lock-file; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			echo "⏭️ NixOS switch skipped in CI as the runner is not a NixOS system"; \
			sudo $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- switch --flake .#runner --no-update-lock-file || exit 0; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			USER=$(NIX_USERNAME) $(NIX_EXEC) run $(NIX_FLAGS) .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage; \
		else \
			echo "Unsupported OS $(OS) for non-CI switch"; \
			exit 1; \
		fi; \
	else \
		if [ "$(NIX_SYSTEM)" = "unsupported" ]; then \
			echo "❌ Unsupported system architecture: $(OS) $(ARCH)"; \
			exit 1; \
		elif [ "$(OS)" = "Darwin" ]; then \
			sudo $(DARWIN_REBUILD) switch --flake .#$(NIX_SYSTEM); \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			sudo $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- switch --flake .#$(NIX_SYSTEM); \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			USER=$(NIX_USERNAME) $(NIX_EXEC) run $(NIX_FLAGS) .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage; \
		else \
			echo "Unsupported OS $(OS) for non-CI switch"; \
			exit 1; \
		fi; \
	fi
	@echo "✅ Nix configuration activated successfully!"

.PHONY: nix-switch-vm
nix-switch-vm:
	@if [ ! -f "./result/bin/run-nixos-vm" ]; then \
		echo "❌ VM binary not found at ./result/bin/run-nixos-vm"; \
		exit 0; \
	fi; \
	export QEMU_OPTS="-m 4096 -smp 2"; \
	printf "sleep 5\nmkdir -p /tmp/test && cd /tmp/test\ncp -r /mnt/shared/* .\n$(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- switch --flake .#runner --no-update-lock-file\npoweroff\n" > vm_commands.txt; \
	timeout 600 ./result/bin/run-nixos-vm -nographic < vm_commands.txt || exit 1; \
	rm -f vm_commands.txt

##@ Shell Installation

.PHONY: shell-install
shell-install:
	@echo "🐠 Setting up Fish shell..."
	@if command -v fish > /dev/null; then \
		fish_path=$$(command -v fish); \
		if ! grep -q "$$fish_path" /etc/shells; then \
			echo "Adding $$fish_path to /etc/shells..."; \
			echo $$fish_path | sudo tee -a /etc/shells; \
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

.PHONY: shell-update
shell-update: shell-install

##@ Docker

.PHONY: docker-build
docker-build:
	@echo "🐳 Building Docker image: $(DOCKER_IMAGE_LATEST) and $(DOCKER_IMAGE_TAGGED)..."
	@docker build -t $(DOCKER_IMAGE_LATEST) -t $(DOCKER_IMAGE_TAGGED) -f Dockerfile .
	@echo "✅ Docker image built: $(DOCKER_IMAGE_LATEST) and $(DOCKER_IMAGE_TAGGED)"
