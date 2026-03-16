HELP_FILE := ./doc/bareline.txt
NVIM_CMD := nvim --headless --noplugin
MINI_DOC_GENERATE_CMD := @$(NVIM_CMD) -u ./scripts/minidoc_init.lua && echo ''
STYLUA_VERSION := $(shell grep stylua .tool-versions | awk '{ print $$2 }')
STYLUA_BIN := $(HOME)/.asdf/installs/stylua/$(STYLUA_VERSION)/bin/stylua

# Neovim plugins versions.
# These are dev dependencies.
MINI_DOC_GIT_COMMIT := v0.17.0
MINI_TEST_GIT_COMMIT := v0.17.0

# Check formatting.
.PHONY: testmft
testfmt: $(STYLUA_BIN)
	stylua --check lua/ scripts/ tests/

# Check docs are up to date.
.PHONY: testdocs
testdocs: deps/mini.doc
	git checkout $(HELP_FILE)
	@$(MINI_DOC_GENERATE_CMD)
	git diff --exit-code $(HELP_FILE)

# Run all unit test.
.PHONY: test
test: deps/mini.test
	$(NVIM_CMD) -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run CI tests.
.PHONY: testci
testci: testfmt testdocs test

# Format.
.PHONY: fmt
fmt: $(STYLUA_BIN)
	stylua lua/ scripts/ tests/

# Update docs.
.PHONY: docs
docs: deps/mini.doc
	$(MINI_DOC_GENERATE_CMD)

deps/mini.test:
	@mkdir -p deps
	git clone --depth 1 --branch $(MINI_TEST_GIT_COMMIT) \
	https://github.com/nvim-mini/mini.test \
	$@

deps/mini.doc:
	@mkdir -p deps
	git clone --depth 1 --branch $(MINI_DOC_GIT_COMMIT) \
	https://github.com/nvim-mini/mini.doc \
	$@

$(STYLUA_BIN):
	asdf plugin add stylua
	asdf install stylua
