# Health and timer scan scenario.
# Collects three groups of WRAM dumps to support brute-force address discovery:
#
#   scan/health/p1_dmg/idle/   — 60 idle baseline frames (P1 takes no damage)
#   scan/health/p1_dmg/hit/    — 120 frames after P2 punches P1
#   scan/health/p2_dmg/idle/   — 60 idle baseline frames (P2 takes no damage)
#   scan/health/p2_dmg/hit/    — 120 frames after P1 punches P2
#   scan/timer/                — 600 consecutive frames for timer discovery
#
# Run via:  dip memory:scan-health-timer

# ── P1 takes damage ───────────────────────────────────────────────────────────

60.times { |i| save_memory "scan/health/p1_dmg/idle/#{i}" }

# Reliable hit: P2 approaches then delivers a multi-punch sequence.
10.times { P2.left 1 }
wait 5
P2.high_punch 3; wait 35
P2.high_punch 3; wait 35
P2.low_kick   3; wait 35

120.times { |i| save_memory "scan/health/p1_dmg/hit/#{i}" }

# ── P2 takes damage ───────────────────────────────────────────────────────────

reload_state

60.times { |i| save_memory "scan/health/p2_dmg/idle/#{i}" }

10.times { P1.right 1 }
wait 5
P1.high_punch 3; wait 35
P1.high_punch 3; wait 35
P1.low_kick   3; wait 35

120.times { |i| save_memory "scan/health/p2_dmg/hit/#{i}" }

# ── Timer scan ────────────────────────────────────────────────────────────────

reload_state

600.times { |i| save_memory "scan/timer/#{i}" }
