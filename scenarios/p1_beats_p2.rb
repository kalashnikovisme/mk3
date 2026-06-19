# P1 (Sub-Zero) beats P2 across two rounds.
# P2 receives no input and stands still the entire match.
#
# Run via:  dip scenario scenarios/p1_beats_p2.rb

APPROACH_FRAMES       = 15   # frames P1 walks right to close the gap
ICE_BALL_RECOVERY     = 30   # frames to let the projectile travel before following up
COMBO_RECOVERY        = 12   # frames between combo attempts (hit-stun + reset)
PUSH_FORWARD_FRAMES   = 8    # frames P1 walks right after each combo to stay in range
COMBOS_PER_ROUND      = 5    # easily enough to deplete 166 HP (combo_4 = ~6 hits)
ROUND_TRANSITION_WAIT = 300  # ~5 s at 60 fps to clear KO/victory/round-banner screens

2.times do |round|
  P1.right APPROACH_FRAMES
  screenshot "round#{round + 1}_approach"

  P1.ice_ball
  screenshot "round#{round + 1}_ice_ball"
  wait ICE_BALL_RECOVERY

  COMBOS_PER_ROUND.times do |i|
    P1.combo_4
    screenshot "round#{round + 1}_combo#{i + 1}_hit"
    wait COMBO_RECOVERY
    P1.right PUSH_FORWARD_FRAMES
    screenshot "round#{round + 1}_combo#{i + 1}_push"
  end

  wait ROUND_TRANSITION_WAIT
  screenshot "round#{round + 1}_end"
end
