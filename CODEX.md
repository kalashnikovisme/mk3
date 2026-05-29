# CODEX.md — Domain Glossary

| Term              | Definition |
|-------------------|-----------|
| Match             | A complete contest between two fighters, consisting of multiple Rounds. Best-of-3 by default. |
| Round             | A single fight within a Match. A Round ends when one fighter's health reaches zero or time expires. |
| Frame             | One game engine tick. All game state is sampled per frame. SNES runs at ~60 fps. |
| GameState         | Complete snapshot of the game at a single Frame: both FighterStates, round number, timer, fight status. |
| FighterState      | State of one fighter at a Frame: health, position, facing, animation, hitstun, blockstun, knockdown, airborne. |
| Observation       | Normalized, agent-facing view of GameState. Values in [0, 1]. No raw memory addresses. |
| Action            | Discrete decision produced by an Agent. Symbolic name (e.g. `:low_punch`). |
| Reward            | Scalar feedback signal for a frame transition. Composed of named components with weights. |
| InputSequence     | Timed sequence of controller button states spanning N frames. |
| ControllerInput   | A single frame's set of button states sent to the emulator. |
| Agent             | Entity that maps Observation → Action. May be rule-based, imitation-learned, or RL-trained. |
| Policy            | The function inside an Agent that determines Actions from Observations. |
| FacingDirection   | `:left` or `:right`. Determines which direction is "forward" for the fighter. |
| AnimationState    | Current animation playing on a fighter: name, frame index within animation, total frames. |
| Hitstun           | State where a fighter cannot act because they were just hit. |
| Blockstun         | State where a fighter cannot act because they just blocked an attack. |
| Knockdown         | State where a fighter has been knocked to the ground. |
| Wakeup            | Transition from Knockdown back to standing — a vulnerable moment. |
| Combo             | Sequence of attacks that chain together during Hitstun. |
| Projectile        | A game object launched by a fighter (e.g. fireball). |
| Distance          | Absolute pixel distance between the two fighters' X positions. |
| EmulatorAdapter   | Ruby abstraction over a specific emulator binary and its communication protocol. |
| GameAdapter       | Ruby abstraction over a specific game: memory layout, inputs, actions, menus, lifecycle. |
| BridgeServer      | TCP server in Ruby that the Lua script inside BizHawk connects to. |
| MemoryMap         | Module of WRAM addresses for a specific game on a specific platform. |
| InputMap          | Module mapping logical button names to emulator button strings. |
| ActionSpace       | Module defining available Actions and their InputSequence translations. |
| ObservationSpace  | Module normalizing GameState into Observation. |
| RewardFunction    | Configurable function computing Reward from two consecutive GameStates. |
| MenuNavigator     | Class driving a game's menus autonomously via timed button press sequences. |
| Recorder          | Writes gameplay sessions to JSONL: (frame, observation, action, reward). |
| DatasetExporter   | Reads JSONL recordings and exports structured datasets for ML pipelines. |
| SaveState         | Emulator snapshot of complete machine state, used to reset to a known point. |
| MatchRunner       | Drives one Match frame-by-frame, coordinating emulator, game adapter, agents, recorder. |
| HumanVsAI        | Runtime mode: human controls one side, AI controls the other. |
| AIVsAI           | Runtime mode: both sides controlled by AI agents, fully autonomous. |
| SpectatorMode     | Runtime mode: trained model fights while user watches (AI on both sides or one side). |
