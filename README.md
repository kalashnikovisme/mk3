# FightingAI

Ruby framework for training AI agents to play fighting games through real emulators.

## Local Development

### Prerequisites

Allow Docker to connect to your X display (run once per session):

```bash
xhost +local:docker
```

### Installing Dip

**macOS / Linux (Homebrew):**
```bash
brew tap bibendi/dip
brew install dip
```

**Linux (RubyGems):**
```bash
gem install dip
```

**Windows:** Use WSL2, then follow the Linux instructions inside WSL.

**Any OS with Ruby:**
```bash
gem install dip
```

Precompiled binaries are also available at the [Dip releases page](https://github.com/bibendi/dip/releases).

### Setup

```bash
dip provision
```

This builds the Docker image (Ruby 4.0 + RetroArch + xdotool), installs gem dependencies, and grants X11 access.

### Daily Commands

| Command | Description |
|---|---|
| `dip shell` | Open a shell in the container |
| `dip bundle` | Run bundler |
| `dip ruby` | Run a Ruby script |
| `dip rspec` | Run RSpec tests |
| `dip rubocop` | Run RuboCop linter |
| `dip learn` | Record AI vs AI self-play to `data/recordings/mk3/` |
| `dip watch-match` | Replay a recorded match |
| `dip play-vs-ai` | Play against the trained AI |

### Notes

- `dip learn`, `dip watch-match`, and `dip play-vs-ai` open a RetroArch window on your host display via X11 forwarding. Run `xhost +local:docker` if the window fails to appear.
- Match save states live in `data/matches/`. At least one `.state` file is required before running `dip learn`.
- ROM (`mk3.sfc`) and the snes9x libretro core are expected at their default paths inside the container.
