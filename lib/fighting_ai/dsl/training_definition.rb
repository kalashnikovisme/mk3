module FightingAI
  module DSL
    class DatasetDefinition
      def initialize
        @recordings_path = nil
      end

      def recordings_path(path = nil)
        path ? @recordings_path = path : @recordings_path
      end
    end

    class RewardDefinition
      attr_reader :components

      def initialize
        @components = []
      end

      def plus(signal, weight: 1.0)
        @components << { signal: signal.to_sym, sign: :plus, weight: weight.to_f }
      end

      def minus(signal, weight: 1.0)
        @components << { signal: signal.to_sym, sign: :minus, weight: weight.to_f }
      end
    end

    class TrainingDefinition
      attr_reader :training_id, :dataset_definition, :reward_definition

      def initialize(training_id)
        @training_id        = training_id
        @game_id            = nil
        @mode_value         = nil
        @dataset_definition = DatasetDefinition.new
        @reward_definition  = RewardDefinition.new
      end

      def game_id = @game_id
      def mode    = @mode_value

      def game(name)
        @game_id = name.to_sym
      end

      def mode(name = nil)
        name ? @mode_value = name.to_sym : @mode_value
      end

      def dataset(&block)
        @dataset_definition.instance_eval(&block)
      end

      def reward(&block)
        @reward_definition.instance_eval(&block)
      end
    end
  end
end
