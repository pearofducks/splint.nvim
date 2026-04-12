LUA_VERSION := 5.1
BUSTED_WRAPPER := $(shell luarocks --lua-version $(LUA_VERSION) show busted 2>/dev/null \
	| grep -A1 'Commands:' | tail -1 | sed 's/.*(\(.*\))/\1/')
BUSTED := $(shell test -f "$(BUSTED_WRAPPER)" && \
	sed -n "s/.*'\\(.*\\/bin\\/busted\\)'.*/\\1/p" "$(BUSTED_WRAPPER)" 2>/dev/null)

.PHONY: test test-file deps

# Run all tests
test:
	@test -n "$(BUSTED)" || { echo "busted not found. Run: make deps"; exit 1; }
	eval "$$(luarocks --lua-version $(LUA_VERSION) path)" && \
		nvim -l "$(BUSTED)" spec/

# Run a single test file: make test-file F=spec/splint_spec.lua
test-file:
	@test -n "$(F)" || { echo "Usage: make test-file F=spec/file_spec.lua"; exit 1; }
	@test -n "$(BUSTED)" || { echo "busted not found. Run: make deps"; exit 1; }
	eval "$$(luarocks --lua-version $(LUA_VERSION) path)" && \
		nvim -l "$(BUSTED)" "$(F)"

# Install test dependencies
deps:
	luarocks --lua-version $(LUA_VERSION) install busted --local
