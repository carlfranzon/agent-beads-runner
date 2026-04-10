PREFIX ?= /usr/local

.PHONY: install uninstall

install:
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 bin/abr $(DESTDIR)$(PREFIX)/bin/abr

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/abr
