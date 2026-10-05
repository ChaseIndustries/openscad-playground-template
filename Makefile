# Symlinked into every project folder, so `make start` works from the root
# or from projects/<slug>/. The REPL picks the project from the cwd.
ROOT := $(patsubst %/,%,$(dir $(realpath $(firstword $(MAKEFILE_LIST)))))
PYTHON ?= python3
# Set when make runs inside projects/<slug>/, empty at the root.
PROJECT := $(firstword $(subst /, ,$(patsubst $(ROOT)/projects/%,%,$(filter $(ROOT)/projects/%,$(CURDIR)))))

.PHONY: start install export

start:
	@$(PYTHON) -c "import prompt_toolkit" 2>/dev/null || $(MAKE) -f $(ROOT)/Makefile install
	@$(PYTHON) $(ROOT)/scripts/qa-repl.py

install:
	$(PYTHON) -m pip install -r $(ROOT)/requirements.txt

# Print STLs land in build/<slug>/. From the root, every project exports.
export:
ifneq ($(PROJECT),)
	@PLAYGROUND_PROJECT=$(PROJECT) bash $(ROOT)/scripts/export_parts.sh
else
	@fail=0; for dir in $(ROOT)/projects/*/; do \
		slug=$$(basename "$$dir"); \
		[ -f "$$dir/repl-config.json" ] || continue; \
		echo "== $$slug"; \
		PLAYGROUND_PROJECT=$$slug bash $(ROOT)/scripts/export_parts.sh || fail=1; \
		echo; \
	done; exit $$fail
endif
