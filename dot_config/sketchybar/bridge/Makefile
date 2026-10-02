OS_BUILD := $(shell sw_vers -buildVersion)

all:
	@[ "$$(cat .os-build 2>/dev/null)" = "$(OS_BUILD)" ] || { rm -rf network_load/bin menus/bin; echo "$(OS_BUILD)" > .os-build; }
	(cd network_load && $(MAKE)) >/dev/null
	(cd menus && $(MAKE)) >/dev/null
