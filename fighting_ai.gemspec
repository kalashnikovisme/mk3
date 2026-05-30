require_relative "lib/fighting_ai/version"

Gem::Specification.new do |spec|
  spec.name    = "fighting_ai"
  spec.version = FightingAI::VERSION
  spec.authors = ["Pavel Kalashnikov"]
  spec.email   = ["kalashnikovisme@gmail.com"]

  spec.summary     = "A reusable framework for training AI agents to play fighting games through real emulators."
  spec.description = "FightingAI connects to real emulators, reads game state, sends controller inputs, and provides a clean architecture for imitation learning and reinforcement learning in fighting games."
  spec.homepage    = "https://github.com/purple-magic/fighting_ai"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir["lib/**/*", "lua/**/*", "docs/**/*", "*.md"]

  spec.add_dependency "json",     "~> 2.0"
  spec.add_dependency "colorize", "~> 1.0"

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rspec-its", "~> 1.3"
end
