require "json"
require "open3"
require "timeout"

module FightingAI
  module Training
    # PPO policy backed by a Python/PyTorch subprocess.
    #
    # All neural-network computation runs in the Python server (bin/ppo_server.py).
    # Ruby communicates over stdin/stdout using newline-delimited JSON so that the
    # entire Ruby API stays clean and no Python code leaks into the training layer.
    #
    # Protocol:
    #   forward: { cmd: "forward", obs: [Float, ...] }
    #            → { action_index: Integer, log_prob: Float, value: Float }
    #
    #   update:  { cmd: "update", transitions: [{obs:, action:, reward:, log_prob:, value:, done:}, ...] }
    #            → { policy_loss: Float, value_loss: Float, entropy: Float, total_loss: Float }
    #
    #   save:    { cmd: "save", path: "..." }  → { ok: true }
    #   load:    { cmd: "load", path: "..." }  → { ok: true }
    class Policy
      PYTHON_SERVER   = File.expand_path("../../../bin/ppo_server.py", __dir__).freeze
      STARTUP_TIMEOUT = 30

      def initialize(obs_dim:, action_dim:, python: "python3")
        @obs_dim    = obs_dim
        @action_dim = action_dim
        @python     = python
        start_server
      end

      def forward(obs_vector, action_index: nil)
        payload = { cmd: "forward", obs: obs_vector }
        payload[:action_index] = action_index unless action_index.nil?
        resp = request(payload)
        {
          action_index: resp["action_index"],
          log_prob:     resp["log_prob"],
          value:        resp["value"]
        }
      end

      def update(transitions)
        payload = transitions.map do |t|
          { obs: t[:obs], action: t[:action], reward: t[:reward],
            log_prob: t[:log_prob], value: t[:value], done: t[:done] }
        end
        resp = request(cmd: "update", transitions: payload)
        {
          policy_loss: resp["policy_loss"],
          value_loss:  resp["value_loss"],
          entropy:     resp["entropy"],
          total_loss:  resp["total_loss"]
        }
      end

      def save(path)
        request(cmd: "save", path: path)
      end

      def load(path)
        request(cmd: "load", path: path)
      end

      def stop
        @stdin&.close
        @process&.wait
      rescue
        nil
      end

      private

      def start_server
        cmd = [@python, PYTHON_SERVER,
               "--obs-dim", @obs_dim.to_s,
               "--act-dim", @action_dim.to_s]

        @stdin, @stdout, @stderr, @process = Open3.popen3(*cmd)
        @stdin.sync  = true
        @stdout.sync = true

        ready = Timeout.timeout(STARTUP_TIMEOUT) { @stdout.readline.strip }
        return if ready == "ready"

        raise "PPO server startup error: #{ready}"
      rescue Timeout::Error
        err = begin; @stderr.read_nonblock(8192); rescue; ""; end
        raise "PPO server did not start within #{STARTUP_TIMEOUT}s.\nstderr: #{err}"
      end

      def request(payload)
        @stdin.puts(JSON.generate(payload))
        JSON.parse(@stdout.readline)
      rescue EOFError, IOError => e
        err = begin; @stderr.read_nonblock(8192); rescue; ""; end
        raise "PPO server connection lost: #{e.message}\nstderr: #{err}"
      end
    end
  end
end
