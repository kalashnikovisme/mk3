.PHONY: install learn show play

install:
	@echo "Installing Ruby dependencies..."
	bundle install
	@mkdir -p data/recordings/mk3
	@echo ""
	@echo "Done. BizHawk setup (required before running any command):"
	@echo "  1. Install BizHawk (https://tasvideos.org/BizHawk/ReleaseHistory)"
	@echo "  2. Load your Mortal Kombat 3 (SNES) ROM."
	@echo "  3. Save a state in slot 1 at the VS mode character select screen."
	@echo "  4. When prompted by a make command: Tools → Lua Console → Open → lua/bizhawk_bridge.lua"

learn:
	bundle exec ruby bin/learn

show:
	bundle exec ruby bin/show

play:
	bundle exec ruby bin/play
