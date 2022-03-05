PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

install:
	install -m 0755 plx $(BINDIR)/plx
	ln -sf $(BINDIR)/plx $(BINDIR)/plx-sh

