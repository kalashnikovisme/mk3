module FightingAI
  module Game
    module MortalKombat3
      # Character registry for MK3 (SNES version).
      # Each entry maps symbolic name => selection screen metadata.
      # cursor_index: position in the character select grid (row-major, 0-based)
      module Characters
        ROSTER = {
          liu_kang:    { cursor_index: 0,  display_name: "Liu Kang"    },
          kung_lao:    { cursor_index: 1,  display_name: "Kung Lao"    },
          kano:        { cursor_index: 2,  display_name: "Kano"        },
          sonya:       { cursor_index: 3,  display_name: "Sonya"       },
          shang_tsung: { cursor_index: 4,  display_name: "Shang Tsung" },
          smoke:       { cursor_index: 5,  display_name: "Smoke"       },
          sub_zero:    { cursor_index: 6,  display_name: "Sub-Zero"    },
          nightwolf:   { cursor_index: 7,  display_name: "Nightwolf"   },
          jax:         { cursor_index: 8,  display_name: "Jax"         },
          stryker:     { cursor_index: 9,  display_name: "Stryker"     },
          sindel:      { cursor_index: 10, display_name: "Sindel"      },
          sektor:      { cursor_index: 11, display_name: "Sektor"      },
          cyrax:       { cursor_index: 12, display_name: "Cyrax"       },
          kabal:       { cursor_index: 13, display_name: "Kabal"       },
          sheeva:      { cursor_index: 14, display_name: "Sheeva"      }
        }.freeze

        POOLS = {
          all:    ROSTER.keys,
          ninjas: %i[smoke sub_zero sektor cyrax],
          humans: %i[liu_kang kung_lao kano sonya jax stryker nightwolf sindel kabal sheeva],
          bosses: %i[shang_tsung]
        }.freeze

        def self.all
          ROSTER
        end

        def self.pool(name)
          POOLS.fetch(name.to_sym) { raise ArgumentError, "Unknown character pool: #{name}" }
        end

        def self.cursor_index_for(character_name)
          ROSTER.fetch(character_name.to_sym) { raise ArgumentError, "Unknown character: #{character_name}" }
            .fetch(:cursor_index)
        end
      end
    end
  end
end
