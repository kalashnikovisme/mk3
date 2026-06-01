# Health address verification scenario.
# Collects three phases of WRAM dumps to isolate individual player health changes:
#
#   known/health/baseline/   — idle frames (both players standing, no input)
#   known/health/walk/       — P1 walks right+left (no combat, health should stay constant)
#   known/health/p1_hit/     — frames after P2 punches P1 (P1 health should decrease)
#   known/health/p2_hit/     — frames after P1 punches P2 (P2 health should decrease)
#
# Run via: dip memory:verify-known-addresses  (included automatically)

# ── Phase 1: idle baseline ────────────────────────────────────────────────────

20.times { |i| save_memory "known/health/baseline/#{i}" }

# ── Phase 2: P1 walks — health should remain constant ────────────────────────

10.times { P1.right 1 }
10.times { P1.left  1 }
20.times { |i| save_memory "known/health/walk/#{i}" }

# ── Phase 3: P2 punches P1 ────────────────────────────────────────────────────

reload_state
P2.high_punch 3
wait 30
60.times { |i| save_memory "known/health/p1_hit/#{i}" }

# ── Phase 4: P1 punches P2 ────────────────────────────────────────────────────

reload_state
P1.high_punch 3
wait 30
60.times { |i| save_memory "known/health/p2_hit/#{i}" }
