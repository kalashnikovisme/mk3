FightingAI.configure_game :mortal_kombat_3 do
  emulator :bizhawk

  inputs do
    button :up
    button :down
    button :left
    button :right
    button :low_punch
    button :high_punch
    button :low_kick
    button :high_kick
    button :block
    button :run
  end

  actions do
    action :idle
    action :walk_forward
    action :walk_back
    action :jump
    action :duck
    action :low_punch
    action :high_punch
    action :low_kick
    action :high_kick
    action :block
    action :run
    action :crouch_punch
    action :crouch_kick
    action :jump_punch
    action :jump_kick
    action :throw_forward
  end
end

FightingAI.training :mk3_imitation do
  game :mortal_kombat_3
  mode :imitation_learning

  dataset do
    recordings_path "data/recordings/mk3"
  end

  reward do
    plus  :damage_dealt, weight: 1.0
    minus :damage_taken, weight: 1.0
    plus  :round_win,    weight: 10.0
    minus :round_loss,   weight: 10.0
  end
end
