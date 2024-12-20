HELP_FILE := ./doc/bareline.txt
CMD_NVIM := nvim --headless --noplugin
ECHASNOVSKI_GH_BASE_URL := https://raw.githubusercontent.com/echasnovski
CMD_MINI_DOC_GENERATE := @$(CMD_NVIM) -u ./scripts/testdocs_init.lua && echo ''
STYLUA_VERSION := $(shell grep stylua .tool-versions | awk '{ print $$2 }')
STYLUA := $(HOME)/.asdf/installs/stylua/$(STYLUA_VERSION)/bin/stylua

# ACTIONS

# Check formatting.
.PHONY: testmft
testfmt: $(STYLUA)
	stylua --check lua/ scripts/ tests/

# Check docs are up to date.
.PHONY: testdocs
testdocs: deps/lua/doc.lua
	git checkout $(HELP_FILE)
	@$(CMD_MINI_DOC_GENERATE)
	git diff --exit-code $(HELP_FILE)

# Run all unit test.
.PHONY: test
test: deps/lua/test.lua
	$(CMD_NVIM) -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run CI tests.
.PHONY: testci
testci: testfmt testdocs test

# Format.
.PHONY: fmt
fmt: $(STYLUA)
	stylua lua/ scripts/ tests/

# Update docs.
.PHONY: docs
docs: deps/lua/doc.lua
	$(CMD_MINI_DOC_GENERATE)

# FILES

deps/lua/test.lua:
	@mkdir -p deps/lua
	curl $(ECHASNOVSKI_GH_BASE_URL)/mini.test/main/lua/mini/test.lua -o $@

deps/lua/doc.lua:
	@mkdir -p deps/lua
	curl $(ECHASNOVSKI_GH_BASE_URL)/mini.doc/main/lua/mini/doc.lua -o $@

# Install Stylua using asdf (https://asdf-vm.com/).
# <https://github.com/JohnnyMorganz/StyLua>.
$(STYLUA):
	asdf plugin add stylua
	asdf install stylua
