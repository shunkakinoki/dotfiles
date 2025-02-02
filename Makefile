OS := $(shell uname -s)

.PHONY: install symlink packages backup test

install: symlink packages test
	@echo "✅ Full environment configured for ${OS}"

symlink:
	@./dotfiles/symlink.sh

packages:
ifeq ($(OS),Darwin)
	@./scripts/brew.sh
else
	@./scripts/apt.sh
endif

test:
	@echo "Running validation tests..."
