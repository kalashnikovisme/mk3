FRAME_COUNT = 120

FRAME_COUNT.times do |i|
  screenshot "frame_#{format('%03d', i + 1)}"
  wait 1
end
