# P2 coordinate discovery scenario.
# Saves 120 sequential WRAM dumps while P2 walks left.
# Dumps land in /app/data/memory/p2_walk/ named 0.bin … 119.bin.
#
# Run via:  dip memory:find-p2
#           dip scenario scenarios/p2_verification.rb

save_memory "p2_walk/start"

120.times do |i|
  P2.left 1
  save_memory "p2_walk/#{i}"
end
