all:
	@jbuilder build

test:
	@jbuilder runtest

check: test

install:
	@jbuilder install

uninstall:
	@jbuilder uninstall

.PHONY: clean all check test install uninstall

clean:
	jbuilder clean
