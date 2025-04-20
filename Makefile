##@ Variables

# Detect architecture and OS
ARCH := $(shell uname -m)
OS := $(shell uname -s)

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
	elif [ "$(OS)" = "Linux" ] && [ -f /etc/NIXOS ]; then \
		echo "nixosConfigurations"; \
	else \
		echo "homeConfigurations"; \
	fi)
NIX_USERNAME := $(shell \
	if [ "$$CI" = "true" ]; then \
		echo "runner"; \
	elif [ "$(OS)" = "Linux" ] && [ ! -f /etc/NIXOS ]; then \
		echo "ubuntu"; \
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
	@echo "  pr           - Create and push a PR (usage: make pr m='commit message' b='branch-name' t='PR title')"

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
	@echo "🔌 Ensuring Nix daemon is running for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH)"
	@if [ "$(OS)" = "Darwin" ]; then \
		sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist 2>/dev/null || true; \
		sudo launchctl load -w /Library/LaunchDaemons/org.nixos.nix-daemon.plist; \
	elif [ "$(OS)" = "Linux" ]; then \
		sudo systemctl restart nix-daemon.service; \
	else \
		echo "❌ Unsupported OS: $(OS)"; \
		exit 1; \
	fi
	@echo "⏳ Waiting for daemon to initialize..."
	@sleep 3
	@echo "✅ Nix daemon should now be active!"

.PHONY: nix-check
nix-check:
	@echo "🔍 Verifying Nix environment setup for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH)"
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "❌ Nix environment not found. Please ensure Nix is installed and run:"; \
		exit 1; \
	fi
	@echo "✅ Nix environment found!"

.PHONY: nix-install
nix-install:
	@if [ "$(NIX_ENV)" = "not_found" ]; then \
		echo "🚀 Installing Nix environment for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH)"; \
		curl -L https://nixos.org/nix/install | sh; \
	fi
	@echo "✅ Nix environment installed!"

##@ Nix

.PHONY: nix-update
nix-update: nix-build nix-switch

.PHONY: nix-backup
nix-backup:
	@echo "🗄️ Backing up configuration files for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH)"
	@backup_dir="$$HOME/.config/backups/$(shell date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$backup_dir"; \
	if [ -d "$$HOME/.config" ]; then \
		cp -R "$$HOME/.config" "$$backup_dir/" 2>/dev/null || true; \
		echo "✅ Backup created at $$backup_dir"; \
	fi

.PHONY: nix-build
nix-build: nix-connect
	@echo "🏗️ Building Nix configuration for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH)"
	@if [ "$$CI" = "true" ]; then \
		echo "Running in CI"; \
		if [ "$(OS)" = "Darwin" ]; then \
			nix build .#$(NIX_CONFIG_TYPE).runner.system $(NIX_FLAGS) --no-update-lock-file --show-trace; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			nix run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- build --flake .#runner --no-update-lock-file; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			nix build .#$(NIX_CONFIG_TYPE)."runner@$(NIX_SYSTEM)" $(NIX_FLAGS) --no-update-lock-file --show-trace; \
		else \
			echo "Unsupported OS $(OS) for non-CI build"; \
			exit 1; \
		fi; \
	else \
		if [ "$(NIX_SYSTEM)" = "unsupported" ]; then \
			echo "❌ Unsupported system architecture: $(OS) $(ARCH)"; \
			exit 1; \
		elif [ "$(OS)" = "Darwin" ]; then \
			nix build .#$(NIX_CONFIG_TYPE).$(NIX_SYSTEM).system $(NIX_FLAGS) --show-trace; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			sudo $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- build --flake .#$(NIX_SYSTEM); \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			nix build .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)" $(NIX_FLAGS) --show-trace; \
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
	@echo "🔧 Activating Nix configuration for $(NIX_CONFIG_TYPE) on $(OS) $(ARCH)"
	@if [ "$$CI" = "true" ]; then \
		if [ "$(OS)" = "Darwin" ]; then \
			$(DARWIN_REBUILD) switch --flake .#runner --no-update-lock-file; \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			nix build .#$(NIX_CONFIG_TYPE).runner.system $(NIX_FLAGS) --no-update-lock-file --show-trace; \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			nix run .#$(NIX_CONFIG_TYPE)."runner@$(NIX_SYSTEM)".activationPackage; \
		else \
			echo "Unsupported OS $(OS) for non-CI switch"; \
			exit 1; \
		fi; \
	else \
		if [ "$(NIX_SYSTEM)" = "unsupported" ]; then \
			echo "❌ Unsupported system architecture: $(OS) $(ARCH)"; \
			exit 1; \
		elif [ "$(OS)" = "Darwin" ]; then \
			$(DARWIN_REBUILD) switch --flake .#$(NIX_SYSTEM); \
		elif [ "$(NIX_CONFIG_TYPE)" = "nixosConfigurations" ]; then \
			sudo $(NIX_EXEC) run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- switch --flake .#$(NIX_SYSTEM); \
		elif [ "$(NIX_CONFIG_TYPE)" = "homeConfigurations" ]; then \
			nix run .#$(NIX_CONFIG_TYPE)."$(NIX_USERNAME)@$(NIX_SYSTEM)".activationPackage; \
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
	printf "sleep 5\nmkdir -p /tmp/test && cd /tmp/test\ncp -r /mnt/shared/* .\nnix run $(NIX_FLAGS) nixpkgs#nixos-rebuild -- switch --flake .#runner --no-update-lock-file\npoweroff\n" > vm_commands.txt; \
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
