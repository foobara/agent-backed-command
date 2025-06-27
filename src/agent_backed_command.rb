require "foobara/agent"

module Foobara
  class AgentBackedCommand < Foobara::Command
    class << self
      # TODO: does this need to be a Concern for proper inheritance?
      attr_accessor :verbose, :io_out, :io_err, :context, :agent_name, :llm_model, :max_llm_calls_per_minute
    end

    inputs do
      agent_options do
        verbose :boolean
        io_out :duck
        io_err :duck
        context Foobara::Agent::Context, :allow_nil, "The current context of the agent"
        agent_name :string, :allow_nil
        llm_model :string,
                  :allow_nil,
                  one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                  description: "The model to use for the LLM"
        max_llm_calls_per_minute :integer, :allow_nil
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
        # TODO: push this up into a helper in foobara/foobara
        is_global_domain = self.class.foobara_domain.scoped_path.empty?
        unless is_global_domain
          command_classes = self.class.foobara_domain.foobara_all_command(mode: Namespace::LookupMode::DIRECT)
          command_classes -= [self.class]
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
        llm_model: agent_options&.[](:llm_model) || self.class.llm_model,
        max_llm_calls_per_minute: agent_options&.[](:max_llm_calls_per_minute) || self.class.max_llm_calls_per_minute
      )
    end

    def construct_goal_if_needed
      unless self.goal
        goal = self.class.scoped_short_name
        goal = Util.underscore(goal)
        goal = Util.humanize(goal)

        goal = "You are an agent backed command named #{self.class.scoped_short_name}. Your goal is: #{goal}."

        if self.class.description
          goal = "#{goal} If helpful, the command description is: #{self.class.description}. Accomplish this goal."
        end

        @goal = goal
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
      if result_type
        if result_type.extends?(BuiltinTypes[:attributes])
          if result_type.element_types.key?(:message_to_user)
            if result_type.element_types.key?(:result_data)
              agent_outcome.result
            elsif agent_outcome.result[:result_data].is_a?(::Hash)
              { message_to_user: agent_outcome.result[:message_to_user] }.merge(agent_outcome.result[:result_data])
            else
              agent_outcome.result
            end
          else
            agent_outcome.result[:result_data]
          end
        else
          agent_outcome.result[:result_data]
        end
      end
    end

    def agent
      @agent || inputs[:agent]
    end

    def goal
      @goal || inputs[:goal]
    end
  end
end
