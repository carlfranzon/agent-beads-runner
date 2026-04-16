PREFIX ?= /usr/local

.PHONY: install uninstall install-hooks

install:
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 bin/abr $(DESTDIR)$(PREFIX)/bin/abr

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/abr

install-hooks:
	chmod +x .githooks/pre-commit
	git config core.hooksPath .githooks
	@echo "Git hooks installed. ABR_VERSION will be auto-bumped on every commit."
