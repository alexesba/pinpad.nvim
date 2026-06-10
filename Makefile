.PHONY: test

# Run the dependency-free test suite under headless Neovim.
test:
	nvim -l tests/run.lua
