IMAGE_NAME := pipe-nvim-dev
PLUGIN_LUA := lua

.PHONY: lint luacheck luals check docker-build shell clean

# Build Docker image
docker-build:
	@docker build -t $(IMAGE_NAME) .

# Run luacheck (primary linter)
lint: docker-build
	@docker run --rm $(IMAGE_NAME) luacheck $(PLUGIN_LUA)/

# Alias
luacheck: lint
check: lint

# Run lua-language-server (note: vim global warnings are expected for Neovim plugins)
luals: docker-build
	@docker run --rm $(IMAGE_NAME) sh -c '\
		lua-language-server --check $(PLUGIN_LUA)/ --checklevel=Warning 2>&1 >/dev/null; \
		if [ -f /opt/lua-language-server/log/check.json ]; then \
			echo "=== lua-language-server results ==="; \
			cat /opt/lua-language-server/log/check.json | \
				grep -c "undefined-global" | xargs -I{} echo "Undefined global warnings: {} (expected for vim)"; \
			cat /opt/lua-language-server/log/check.json | \
				grep -v "undefined-global" | grep -v "^\[" | grep -v "^{" | grep -v "^}" | grep "code" || echo "No other issues found"; \
		fi'

# Run interactive shell in container for debugging
shell: docker-build
	@docker run --rm -it $(IMAGE_NAME) /bin/bash

# Clean up Docker image
clean:
	@docker rmi $(IMAGE_NAME) 2>/dev/null || true
