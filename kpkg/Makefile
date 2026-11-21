CC ?= gcc
CFLAGS ?= -O2
CFLAGS += -std=gnu17 -Wall -Wextra -Wsign-conversion -Wformat=2 -Werror -Wno-format-truncation -fstack-protector-strong -fPIE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3
LDFLAGS += -pie -Wl,-z,relro,-z,now
PREFIX ?= /usr
DESTDIR ?=

all: kpkg

SRCS := kpkg.c util.c lock.c recipe.c db.c build.c cmds.c snap.c update.c

kpkg: $(SRCS) kpkg.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS)

install: kpkg
	@if [ -z "$(DESTDIR)" ] && [ -z "$$KPKG_FORCE" ] && ! grep -q '^ID="\?kryonux' /etc/os-release 2>/dev/null; then \
	  echo "kpkg: refusing to install into a non-Kryonux system; use DESTDIR for stage3/iso staging" >&2; \
	  exit 1; \
	fi
	install -Dm755 kpkg $(DESTDIR)$(PREFIX)/bin/kpkg

install-box:
	install -Dm755 kpkg-box.sh $(DESTDIR)/usr/local/bin/kpkg

conf:
	install -d $(DESTDIR)/etc/kpkg
	@if [ -f etc/kpkg/kryonux.pub ]; then install -m644 etc/kpkg/kryonux.pub $(DESTDIR)/etc/kpkg/kryonux.pub; fi
	@if [ ! -e $(DESTDIR)/etc/kpkg/kpkg.conf ]; then \
	  install -m644 etc/kpkg/kpkg.conf $(DESTDIR)/etc/kpkg/kpkg.conf; \
	elif ! cmp -s etc/kpkg/kpkg.conf $(DESTDIR)/etc/kpkg/kpkg.conf; then \
	  install -m644 etc/kpkg/kpkg.conf $(DESTDIR)/etc/kpkg/kpkg.conf.dist; \
	  echo "kept existing kpkg.conf, new version: kpkg.conf.dist"; \
	fi

clean:
	rm -f kpkg

.PHONY: all install install-box conf clean
