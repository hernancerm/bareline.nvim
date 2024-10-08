# Run all test files.
test: deps/lua/test.lua
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Download 'mini.nvim' to use its 'mini.test' testing module.
deps/lua/test.lua:
	@mkdir -p deps/lua
	curl https://raw.githubusercontent.com/echasnovski/mini.test/main/lua/mini/test.lua -o $@
