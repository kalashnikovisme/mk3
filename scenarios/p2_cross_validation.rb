# P2 left/right cross-validation scenario.
# Runs two 120-frame sequences: P2 walking left, then (after state reload) P2
# walking right.  CandidateVerifier and P2Finder use these to compute corr_left
# and corr_right for each candidate — a true P2 coordinate shows opposite signs.
#
# Dumps land in:
#   /app/data/memory/p2_left_long/0.bin … 119.bin
#   /app/data/memory/p2_right_long/0.bin … 119.bin
#
# Run via:  dip memory:find-p2  (included automatically)
#           dip scenario scenarios/p2_cross_validation.rb

120.times do |i|
  P2.left 1
  save_memory "p2_left_long/#{i}"
end

reload_state

120.times do |i|
  P2.right 1
  save_memory "p2_right_long/#{i}"
end
