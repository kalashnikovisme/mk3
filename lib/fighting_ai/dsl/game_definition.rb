module FightingAI
  module DSL
    class InputsDefinition
      attr_reader :buttons

      def initialize
        @buttons = []
      end

      def button(name)
        @buttons << name.to_sym
      end
    end

    class ActionsDefinition
      attr_reader :actions

      def initialize
        @actions = []
      end

      def action(name, sequence: nil)
        @actions << { name: name.to_sym, sequence: sequence }
      end
    end

    class GameDefinition
      attr_reader :game_id, :emulator_id, :inputs_definition, :actions_definition, :characters

      def initialize(game_id)
        @game_id             = game_id
        @emulator_id         = nil
        @inputs_definition   = InputsDefinition.new
        @actions_definition  = ActionsDefinition.new
        @characters          = {}
      end

      def emulator(name)
        @emulator_id = name.to_sym
      end

      def inputs(&block)
        @inputs_definition.instance_eval(&block)
      end

      def actions(&block)
        @actions_definition.instance_eval(&block)
      end

      def character(name, id: nil, **attrs)
        @characters[name.to_sym] = { id: id, **attrs }
      end

      def available_buttons
        @inputs_definition.buttons
      end

      def available_actions
        @actions_definition.actions.map { |a| a[:name] }
      end
    end
  end
end
