DART ?= dart
PLUGINS := caelestia caelestia-glassier

.PHONY: deps compile archive

deps:
	cd tool && $(DART) pub get

compile: deps
	@for plugin in $(PLUGINS); do \
	  (cd tool && $(DART) run compile_plugin.dart ../$$plugin/src/caelestia_theme.ht ../$$plugin/plugin.out); \
	done

# Fresh archive each time: packing in append mode would leave a stale entry
# behind if a plugin ever lost a file.
archive: compile
	@for plugin in $(PLUGINS); do \
	  python3 tool/pack_smplug.py $$plugin; \
	done
