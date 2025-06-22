module Foobara
  class AgentBackedCommand < Foobara::Command
    class << self
      # TODO: does this need to be a Concern for proper inheritance?
      attr_accessor :verbose, :io_out, :io_err, :context, :agent_name, :llm_model
    end

    inputs do
      agent_options do
        verbose :boolean, :allow_nil
        io_out :duck
        io_err :duck
        context Foobara::Agent::Context, :allow_nil, "The current context of the agent"
        agent_name :string, :allow_nil
        llm_model :string,
                  :allow_nil,
                  one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                  default: "claude-3-7-sonnet-20250219",
                  description: "The model to use for the LLM"
      end
    end

    def execute
      build_agent_if_needed
      construct_goal_if_needed

      run_agent
      handle_agent_outcome

      agent_result
    end

    attr_writer :goal, :agent
    attr_accessor :agent_outcome

    def build_agent_if_needed
      return if agent

      command_classes = self.class.depends_on

      if command_classes.empty?
        unless self.class.foobara_domain.global?
          command_classes = self.class.foobara_domain.foobara_all_domain(mode: LookupMode::DIRECT)
        end
      end

      include_message_to_user_in_result = if result_type.extends?(BuiltinTypes[:attributes])
                                            result_type.element_types.key?(:message_to_user)
                                          end

      agent_name = agent_options&.[](:agent_name) || self.class.agent_name || "#{self.class.scoped_short_name}Agent"

      @agent = Foobara::Agent.new(
        command_classes:,
        include_message_to_user_in_result:,
        result_type: self.class.result_type,
        verbose: agent_options&.[](:verbose) || self.class.verbose,
        io_out: agent_options&.[](:io_out) || self.class.io_out,
        io_err: agent_options&.[](:io_err) || self.class.io_err,
        agent_name:,
        context: agent_options&.[](:context) || self.class.context,
        llm_model: agent_options&.[](:llm_model) || self.class.llm_model
      )
    end

    def construct_goal_if_needed
      unless goal
        @goal = if description
                  sentence = self.class.scoped_short_name
                  sentence = Util.underscore(sentence)
                  sentence = Util.humanize(sentence)

                  "#{sentence}."
                end
      end
    end

    def run_agent
      self.agent_outcome = agent.run(goal)
    end

    def handle_agent_outcome
      unless agent_outcome.success?
        agent_outcome.each_error do |error|
          add_error(error)
        rescue HaltError
          nil
        end

        halt!
      end
    end

    def agent_result
      agent_outcome.result
    end

    def agent
      @agent || inputs[:agent]
    end

    def goal
      @goal || inputs[:goal]
    end
  end
end
