# Symlinked into every project folder, so `make start` works from the root
# or from projects/<slug>/. The REPL picks the project from the cwd.
ROOT := $(patsubst %/,%,$(dir $(realpath $(firstword $(MAKEFILE_LIST)))))
PYTHON ?= python3

.PHONY: start install

start:
	@$(PYTHON) -c "import prompt_toolkit" 2>/dev/null || $(MAKE) -f $(ROOT)/Makefile install
	@$(PYTHON) $(ROOT)/scripts/qa-repl.py

install:
	$(PYTHON) -m pip install -r $(ROOT)/requirements.txt
