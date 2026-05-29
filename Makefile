.PHONY: install learn watch-match play-vs-ai

CORE_PATH := $(HOME)/.config/retroarch/cores/snes9x_libretro.so
ROM_PATH  := $(CURDIR)/mk3.sfc

install:
	bundle install
	mkdir -p data/recordings/mk3
	sudo apt-get install -y retroarch xdotool
	retroarch --core-updater-download snes9x || true
	mkdir -p $(HOME)/.config/retroarch/cores

learn:
	bundle exec ruby bin/learn

watch-match:
	bundle exec ruby bin/watch-match

play-vs-ai:
	bundle exec ruby bin/play-vs-ai
