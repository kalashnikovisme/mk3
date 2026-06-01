# Timer address verification scenario.
# Records 300 consecutive WRAM snapshots while the round clock runs.
# Each save_memory call takes ~100-200 ms of real time, so 300 saves ≈ 30-60
# real seconds — long enough for the display timer to decrement several counts.
#
# Dumps land in:  known/timer/0.bin … 299.bin
#
# Run via: dip memory:verify-known-addresses  (included automatically)

300.times { |i| save_memory "known/timer/#{i}" }
