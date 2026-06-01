# Memory analysis scenario — runs all address-discovery test cases in sequence.
# Each section reloads the initial match state so every test starts from the
# same position.  Dumps land in subdirectories of /app/data/memory/.
#
# Run via:  dip memory:analyze
#           dip scenario scenarios/memory_analysis.rb

# ── P1 X: monotonically increasing while P1 walks right ──────────────────────

save_memory "p1_x/idle"

P1.right 1
save_memory "p1_x/r1"

P1.right 1
save_memory "p1_x/r2"

P1.right 1
save_memory "p1_x/r3"

P1.right 1
save_memory "p1_x/r4"

P1.right 1
save_memory "p1_x/r5"

# ── P2 X: monotonically changing while P2 walks left ─────────────────────────

reload_state
save_memory "p2_x/idle"

P2.left 1
save_memory "p2_x/l1"

P2.left 1
save_memory "p2_x/l2"

P2.left 1
save_memory "p2_x/l3"

P2.left 1
save_memory "p2_x/l4"

P2.left 1
save_memory "p2_x/l5"

# ── Distance: bracket idle between far and close ──────────────────────────────

reload_state
save_memory "distance/idle"

P1.right 30
save_memory "distance/far"

P1.left 60
save_memory "distance/close"

# ── Facing: walk P1 all the way through P2, expecting a facing flip ───────────

reload_state
save_memory "facing/before_cross"

P1.right 120

save_memory "facing/after_cross"

# ── Health: P1 high-punches; look for P2 health decrease ─────────────────────

reload_state
save_memory "health/full"

P1.high_punch 1
wait 30

save_memory "health/damaged"

# ── Timer: 1-second ticks, expect a step of −1 per snapshot ──────────────────

reload_state
save_memory "timer/t99"

wait 60
save_memory "timer/t98"

wait 60
save_memory "timer/t97"
