PREFIX  ?= $(HOME)/.local
LIBDIR  := $(PREFIX)/lib/kbs
LOADER  := $(HOME)/.bashrc.d/kbs

.PHONY: install uninstall test

install:
	install -d "$(LIBDIR)"
	cp kbs.bash kbs.awk rules.dat "$(LIBDIR)/"
	install -d "$(HOME)/.bashrc.d"
	printf 'source %s/kbs.bash\n' "$(LIBDIR)" > "$(LOADER)"
	@echo "kbs installed to $(LIBDIR); loader at $(LOADER). Open a new shell."

uninstall:
	rm -rf "$(LIBDIR)"
	rm -f  "$(LOADER)"
	@echo "kbs uninstalled."

test:
	tests/run.sh
