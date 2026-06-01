# Candidate verification scenario.
# Produces 120-frame motion sequences for P1 (walking right) and P2 (walking
# left).  CandidateVerifier reads these to score monotonicity, average delta,
# delta variance, and direction changes for each candidate address.
#
# Run via:  dip memory:verify
#           dip scenario scenarios/candidate_verification.rb

save_memory "start"

120.times do |i|
  P1.right 1
  save_memory "p1_right/#{i}"
end

reload_state

save_memory "start"

120.times do |i|
  P2.left 1
  save_memory "p2_left/#{i}"
end
