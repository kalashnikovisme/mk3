require "json"
require "msgpack"
require "open3"
require "timeout"

module FightingAI
  module Training
    # PPO policy backed by a Python/PyTorch subprocess.
    #
    # All neural-network computation runs in the Python server (bin/ppo_server.py).
    # Ruby communicates over binary stdin/stdout using length-prefixed msgpack frames.
    # The startup handshake is a one-time JSON+newline exchange (not on the hot path).
    #
    # Protocol (after startup):
    #   Each message: 4-byte big-endian uint32 length, then msgpack payload.
    #
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
        @stdin.binmode
        @stdout.binmode
        @stdin.sync  = true
        @stdout.sync = true

        line  = Timeout.timeout(STARTUP_TIMEOUT) { @stdout.readline.strip }
        msg   = JSON.parse(line)
        raise "PPO server startup error: #{line}" unless msg["ready"]

        $stdout.puts "PPO device: #{msg["device"]}"
        $stdout.flush
      rescue Timeout::Error
        err = begin; @stderr.read_nonblock(8192); rescue; ""; end
        raise "PPO server did not start within #{STARTUP_TIMEOUT}s.\nstderr: #{err}"
      end

      def request(payload)
        data = payload.to_msgpack
        @stdin.write([data.bytesize].pack("N") + data)
        header = @stdout.read(4)
        raise EOFError, "server closed stdout" if header.nil? || header.bytesize < 4
        length = header.unpack1("N")
        MessagePack.unpack(@stdout.read(length))
      rescue EOFError, IOError => e
        err = begin; @stderr.read_nonblock(8192); rescue; ""; end
        raise "PPO server connection lost: #{e.message}\nstderr: #{err}"
      end
    end
  end
end
