# Run all test files
test: deps/lua/test.lua
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Formatting with https://github.com/JohnnyMorganz/StyLua
fmt:
ifeq (, $(shell which stylua))
$(error "No stylua found. Install from: https://github.com/JohnnyMorganz/StyLua")
endif
	stylua lua/ scripts/ tests/

# Download 'mini.nvim' to use its 'mini.test' testing module
deps/lua/test.lua:
	@mkdir -p deps/lua
	curl https://raw.githubusercontent.com/echasnovski/mini.test/main/lua/mini/test.lua -o $@
