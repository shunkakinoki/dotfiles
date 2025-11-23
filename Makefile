##@ Variables

# Include rules from submodule
-include rules/Makefile

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

# Machine detection for automatic host mapping
DETECTED_HOST := $(shell \
	if [ "$(OS)" = "Darwin" ] && [ "$(shell whoami)" = "shunkakinoki" ] && [ "$(ARCH)" = "arm64" ]; then \
		computer_name=$$(scutil --get ComputerName 2>/dev/null || echo ""); \
		if echo "$$computer_name" | grep -q "Shun's MacBook M4"; then \
			echo "galactica"; \
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

##@ Help

# Default target
.PHONY: default
default: help

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  install      - Set up full environment"
	@echo "  setup        - Basic Nix setup"
	@echo "  setup-dev    - Set up local development environment (Nix + submodules + shell)"
	@echo "  dev          - Enter the Nix dev shell"
	@echo "  build        - Build Nix configuration"
	@echo "  switch       - Apply Nix configuration"
	@echo "  update       - Update Nix flake and configurations"
	@echo "  format       - Format Nix files"
	@echo "  format-check - Check Nix formatting"
	@echo "  docker-build - Build the Docker image"
	@echo "  switch-HOST      - Switch to a named host configuration (e.g., make switch-galactica)"
	@echo "  encrypt-key-HOST - Encrypt a key for a named host (e.g., make encrypt-key-galactica KEY_FILE=~/.ssh/id_ed25519)"
	@echo "  decrypt-key-HOST - Decrypt a key for a named host (e.g., make decrypt-key-galactica KEY_FILE=id_ed25519)"
	@echo "  rekey-HOST       - Rekey all secrets for a named host (e.g., make rekey-galactica)"

##@ General

.PHONY: install
install: setup update shell-install

.PHONY: build
build: nix-build

.PHONY: check
check: nix-check

.PHONY: flake-check
flake-check: nix-flake-check

.PHONY: format
format: nix-format

.PHONY: setup
setup: nix-setup

.PHONY: setup-dev
setup-dev: nix-setup git-submodule-sync shell-install

.PHONY: switch
switch: nix-switch

.PHONY: update
update: nix-update shell-update neovim-update

.PHONY: dev
dev: nix-develop

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

.PHONY: nix-develop
nix-develop:
	$(NIX_ALLOW_UNFREE) $(NIX_EXEC) develop $(NIX_FLAGS)

.PHONY: nix-install
nix-install:
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "🚀 Installing Nix environment for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"; \
		curl -L https://nixos.org/nix/install | sh; \
	fi
	@echo "✅ Nix environment installed!"

##@ Nix

.PHONY: nix-update
nix-update: nix-flake-update nix-build nix-switch

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
		echo "🤖 Running in CI/Docker environment"; \
		if [ "$(OS)" = "Darwin" ]; then \
			$(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#$(NIX_CONFIG_TYPE).runner.system $(NIX_FLAGS) --impure --no-update-lock-file --show-trace; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			$(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#nixosConfigurations.runner.config.system.build.toplevel $(NIX_FLAGS) --impure --no-update-lock-file --show-trace; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			$(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage $(NIX_FLAGS) --impure --no-update-lock-file --show-trace; \
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
			sudo $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- build --flake .#$(NIX_SYSTEM) --impure; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			$(NIX_ALLOW_UNFREE) $(NIX_EXEC) build .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage $(NIX_FLAGS) --impure --show-trace; \
		else \
			echo "Unsupported OS $(OS) for non-CI build"; \
			exit 1; \
		fi; \
	fi
	@echo "✅ Nix configuration built successfully!"

.PHONY: nix-flake-check
nix-flake-check:
	@echo "🔍 Checking Nix flake configuration..."
	@$(NIX_ALLOW_UNFREE) $(NIX_EXEC) flake check --all-systems --impure $(NIX_FLAGS)
	@echo "✅ Nix flake check completed successfully"

.PHONY: nix-flake-update
nix-flake-update: nix-connect
	@echo "♻️ Refreshing flake.lock file..."
	@if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
		echo "Bypassing flake update in CI/Docker"; \
	else \
		$(NIX_EXEC) flake update $(NIX_FLAGS); \
	fi
	@echo "✅ flake.lock updated!"

.PHONY: nix-format
nix-format: nix-format-clear-cache
	@echo "🧹 Formatting Nix files..."
	@$(NIX_EXEC) fmt -- --clear-cache
	@echo "✅ Formatting complete"

.PHONY: nix-format-clear-cache
nix-format-clear-cache:
	@echo "🧹 Clearing Nix cache..."
	@$(NIX_EXEC) fmt -- --clear-cache
	@echo "✅ Cache cleared"

.PHONY: nix-format-check
nix-format-check: nix-format-clear-cache
	@echo "🔍 Checking Nix file formatting..."
	@$(NIX_EXEC) fmt -- --fail-on-change
	@echo "✅ All Nix files are properly formatted"

.PHONY: nix-switch
nix-switch:
	@echo "🔧 Activating Nix configuration for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH) for USER=$(NIX_USERNAME)"
	@if [ "$$CI" = "true" ] || [ "$$IN_DOCKER" = "true" ]; then \
		if [ "$(OS)" = "Darwin" ]; then \
			sudo $(NIX_ALLOW_UNFREE) $(DARWIN_REBUILD) switch --flake .#runner --impure --no-update-lock-file; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			echo "⏭️ NixOS switch skipped in CI as the runner is not a NixOS system"; \
			sudo $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure nixpkgs#nixos-rebuild -- switch --flake .#runner --no-update-lock-file || exit 0; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			USER=$(NIX_USERNAME) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage; \
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
				sudo $(NIX_ALLOW_UNFREE) $(DARWIN_REBUILD) switch --flake .#$(HOST) --impure; \
			elif [ -n "$(DETECTED_HOST)" ]; then \
				echo "Auto-detected host: $(DETECTED_HOST)"; \
				sudo $(NIX_ALLOW_UNFREE) $(DARWIN_REBUILD) switch --flake .#$(DETECTED_HOST) --impure; \
			else \
				sudo $(NIX_ALLOW_UNFREE) $(DARWIN_REBUILD) switch --flake .#$(NIX_SYSTEM) --impure; \
			fi; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			sudo $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure nixpkgs#nixos-rebuild -- switch --flake .#$(NIX_SYSTEM); \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			USER=$(NIX_USERNAME) $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage; \
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

##@ Nix Offline Mode

.PHONY: nix-build-offline 
nix-build-offline:
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
nix-switch-offline:
	@echo "🔧 Activating Nix configuration in offline mode"
	@if [ "$(OS)" = "Darwin" ]; then \
		NIX_OFFLINE=1 sudo $(NIX_ALLOW_UNFREE) $(DARWIN_REBUILD) switch --flake .#galactica --impure --offline; \
	elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
		NIX_OFFLINE=1 sudo $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure nixpkgs#nixos-rebuild -- switch --flake .#runner --no-update-lock-file --offline || exit 0; \
	elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
		NIX_OFFLINE=1 USER=$(NIX_USERNAME) sudo $(NIX_ALLOW_UNFREE) $(NIX_EXEC) run $(NIX_FLAGS) --impure .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage --offline; \
	else \
		echo "Unsupported OS $(OS) for offline switch"; \
		exit 1; \
	fi
	@echo "✅ Nix configuration activated successfully in offline mode!"

nix-setup-offline:
	@echo "🔧 Setting up offline environment"
	@mkdir -p ~/.cache/nix
	@echo "✅ Offline environment setup complete"

##@ Offline Mode

##@ Named Hosts Specific Targets

.PHONY: switch-%
switch-%:
	@$(MAKE) nix-switch HOST=$*

.PHONY: encrypt-key-%
encrypt-key-%:
	@$(MAKE) encrypt-key HOST=$* KEY_FILE=$(KEY_FILE)

.PHONY: decrypt-key-%
decrypt-key-%:
	@$(MAKE) decrypt-key HOST=$* KEY_FILE=$(KEY_FILE)

.PHONY: rekey-%
rekey-%:
	@$(MAKE) rekey HOST=$*

##@ Agenix Secrets Management

.PHONY: encrypt-key
encrypt-key:
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
decrypt-key:
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
rekey:
	@if [ -z "$(HOST)" ]; then \
		echo "❌ HOST variable is not set. Usage: make rekey HOST=<hostname>"; \
		exit 1; \
	fi
	@echo "🔑 Rekeying all secrets for host $(HOST)..."
	@cd named-hosts/$(HOST) && agenix --rekey
	@echo "✅ Rekeying complete for $(HOST)."

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

##@ Neovim

.PHONY: neovim-dev
neovim-dev:
	@echo "🔧 Setting up local Neovim development environment..."
	@if [ -L "$(HOME)/.config/nvim" ]; then \
		rm "$(HOME)/.config/nvim"; \
	fi
	@mkdir -p "$(HOME)/.config/nvim"
	@ln -sf "$(PWD)/config/nvim/init.lua" "$(HOME)/.config/nvim/init.lua"
	@ln -sf "$(PWD)/config/nvim/nvim-pack-lock.json" "$(HOME)/.config/nvim/nvim-pack-lock.json"
	@echo "✅ Local Neovim development environment ready"

.PHONY: neovim-update
neovim-update:
	@echo "📦 Updating neovim plugins..."
	@nvim --headless +"lua vim.pack.update()" +qa
	@echo "✅ Neovim plugins updated"

.PHONY: neovim-sync
neovim-sync:
	@echo "🔄 Syncing neovim plugins..."
	@nvim --headless +"lua vim.pack.sync()" +qa
	@echo "✅ Neovim plugins synced"


##@ Git Submodule

.PHONY: git-submodule-sync
git-submodule-sync:
	@echo "🔁 Syncing and updating git submodules..."
	@git submodule sync
	@git submodule update --init --recursive
	@echo "✅ Submodules synced and updated"

