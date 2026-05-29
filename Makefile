.PHONY: install learn watch-match play-vs-ai

CORE_PATH := /usr/lib/x86_64-linux-gnu/libretro/snes9x_libretro.so
ROM_PATH  := $(CURDIR)/mk3.sfc

install:
	bundle install
	mkdir -p data/recordings/mk3
	sudo apt-get install -y retroarch libretro-snes9x xdotool

learn:
	ROM_PATH="$(ROM_PATH)" CORE_PATH="$(CORE_PATH)" bundle exec ruby bin/learn

watch-match:
	ROM_PATH="$(ROM_PATH)" CORE_PATH="$(CORE_PATH)" bundle exec ruby bin/watch-match

play-vs-ai:
	ROM_PATH="$(ROM_PATH)" CORE_PATH="$(CORE_PATH)" bundle exec ruby bin/play-vs-ai
