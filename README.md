# Foobara::AgentBackedCommand

Allows a quick, easy way to have a command's execute method handled by a Foobara::Agent. Similar to
the Foobara::LlmBackedCommand, you can just specify whatever parts of the command's anatomy other
than the execute method, and it will be handled by the Agent.

## Installation

Typical stuff: add `gem "foobara-agent-backed-command"` to your Gemfile or .gemspec file. Or even just
`gem install foobara-agent-backed-command` if just playing with it directly in scripts.

## Usage

You can make an AgentBackedCommand by subclassing Foobara::AgentBackedCommand.
You can specify whatever inputs/result types you want or you can omit them.

Here's a very short example from the loan-origination foobara demo domain:

```ruby
class FoobaraDemo::LoanOrigination::ReviewAllLoanFilesNeedingReview < Foobara::AgentBackedCommand
end
```

A more fleshed-out version might be:

```ruby
class FoobaraDemo::LoanOrigination::ReviewAllLoanFilesNeedingReview < Foobara::AgentBackedCommand
  description "Checks each LoanFile needing review against all requirements in its CreditPolicy. " \
                "If any requirement is not satisfied, it will be denied. Otherwise, approved"
  verbose

  result do
    approved [{ applicant_name: :string }]
    denied [{ applicant_name: :string, denied_reasons: [:denied_reason] }]
  end
end
```

Notice how we don't need to specify an execute method. The AgentBackedCommand choose which commands from its
domain to execute. Here's some example output of running the above command:

```
$ loan-origination ReviewAllLoanFilesNeedingReview --agent-options-verbose
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ListCommands")
Foobara::Agent::ListCommands.run
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview")
FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview.run
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::FindCreditPolicy")
FoobaraDemo::LoanOrigination::FindCreditPolicy.run(credit_policy: 64)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::DenyLoanFile")
FoobaraDemo::LoanOrigination::DenyLoanFile.run(loan_file: 64, credit_score_used: 650, denied_reasons: ["low_credit_score"])
Command FoobaraDemo::LoanOrigination::DenyLoanFile failed {"data.loan_file.cannot_transition_state" => {key: "data.loan_file.cannot_transition_state", path: [:loan_file], runtime_path: [], category: :data, symbol: :cannot_transition_state, message: "Cannot perform deny transition for loan file 64 from needs_review. Expected state to be one of: [:in_review]. Did you forget to start the review?", context: {loan_file_id: 64, current_state: :needs_review, required_states: [:in_review], attempted_transition: :deny}, is_fatal: false}}
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::StartUnderwriterReview")
FoobaraDemo::LoanOrigination::StartUnderwriterReview.run(loan_file: 64)
FoobaraDemo::LoanOrigination::DenyLoanFile.run(loan_file: 64, credit_score_used: 650, denied_reasons: ["low_credit_score"])
FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview.run
FoobaraDemo::LoanOrigination::FindCreditPolicy.run(credit_policy: 65)
FoobaraDemo::LoanOrigination::StartUnderwriterReview.run(loan_file: 65)
FoobaraDemo::LoanOrigination::DenyLoanFile.run(loan_file: 65, credit_score_used: 750, denied_reasons: ["insufficient_pay_stubs_provided"])
FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview.run
FoobaraDemo::LoanOrigination::FindCreditPolicy.run(credit_policy: 66)
FoobaraDemo::LoanOrigination::StartUnderwriterReview.run(loan_file: 66)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::ApproveLoanFile")
FoobaraDemo::LoanOrigination::ApproveLoanFile.run(loan_file: 66, credit_score_used: 750)
FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview.run
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ReviewAllLoanFilesNeedingReviewAgent::NotifyUserThatCurrentGoalHasBeenAccomplished")
Foobara::Agent::ReviewAllLoanFilesNeedingReviewAgent::NotifyUserThatCurrentGoalHasBeenAccomplished.run(approved: [{"applicant_name" => "Fumiko"}], denied: [{"applicant_name" => "Barbara", "denied_reasons" => ["low_credit_score"]}, {"applicant_name" => "Basil", "denied_reasons" => ["insufficient_pay_stubs_provided"]}])
approved: [
  {
    applicant_name: "Fumiko"
  }
],
denied: [
  {
    applicant_name: "Barbara",
    denied_reasons: [
      "low_credit_score"
    ]
  },
  {
    applicant_name: "Basil",
    denied_reasons: [
      "insufficient_pay_stubs_provided"
    ]
  }
]
```

Here, we used a CLI connector to let us run it from the command line. 
We ran it with the `--agent-options-verbose` flag to get verbose output from command. We can see
all of the commands from the domain it ran to accomplish its goal. Also, it gave us its result in the
format we wanted. We can connect this command in any way we'd connect any other Foobara command.

Here's an example with inputs:

```ruby
module FoobaraDemo
  module LoanOrigination
    class ReviewLoanFile < Foobara::AgentBackedCommand
      description "Performs a review of the given LoanFile by checking it " \
                  "against all requirements in its CreditPolicy. " \
                  "If any requirement is not satisfied, it will be denied. Otherwise, approved"
      verbose

      add_inputs do
        loan_file LoanFile, :required
      end

      result LoanFile::UnderwriterDecision
    end
  end
end
```

running this command in a CLI connector gives the following output:

```
╚loan-origination ReviewLoanFile --agent-options-verbose --loan-file 72
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ListCommands")
Foobara::Agent::ListCommands.run
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::FindCreditPolicy")
FoobaraDemo::LoanOrigination::FindCreditPolicy.run(credit_policy: 72)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::ApproveLoanFile")
FoobaraDemo::LoanOrigination::ApproveLoanFile.run(loan_file: 72, credit_score_used: 750)
Command FoobaraDemo::LoanOrigination::ApproveLoanFile failed {"data.loan_file.cannot_transition_state" => {key: "data.loan_file.cannot_transition_state", path: [:loan_file], runtime_path: [], category: :data, symbol: :cannot_transition_state, message: "Cannot perform approve transition for loan file 72 from needs_review. Expected state to be one of: [:in_review]. Did you forget to start the review?", context: {loan_file_id: 72, current_state: :needs_review, required_states: [:in_review], attempted_transition: :approve}, is_fatal: false}}
FoobaraDemo::LoanOrigination::StartUnderwriterReview.run(loan_file: 72)
FoobaraDemo::LoanOrigination::ApproveLoanFile.run(loan_file: 72, credit_score_used: 750)
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ReviewLoanFileAgent::NotifyUserThatCurrentGoalHasBeenAccomplished")
Foobara::Agent::ReviewLoanFileAgent::NotifyUserThatCurrentGoalHasBeenAccomplished.run(result: {"decision" => "approved", "credit_score_used" => 750})
decision: "approved",
credit_score_used: 750
```

And we can also just run this command directly and use its result programmatically if we want:

```
irb(main):001> outcome = FoobaraDemo::LoanOrigination::ReviewLoanFile.run(loan_file: 71, agent_options: {verbose: true})
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ListCommands")
Foobara::Agent::ListCommands.run
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::FindCreditPolicy")
FoobaraDemo::LoanOrigination::FindCreditPolicy.run(credit_policy: 71)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::StartUnderwriterReview")
FoobaraDemo::LoanOrigination::StartUnderwriterReview.run(loan_file: 71)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::DenyLoanFile")
FoobaraDemo::LoanOrigination::DenyLoanFile.run(loan_file: 71, credit_score_used: 750, denied_reasons: ["insufficient_pay_stubs_provided"])
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ReviewLoanFileAgent::NotifyUserThatCurrentGoalHasBeenAccomplished")
Foobara::Agent::ReviewLoanFileAgent::NotifyUserThatCurrentGoalHasBeenAccomplished.run(result: {"decision" => "denied", "credit_score_used" => 750, "denied_reasons" => ["insufficient_pay_stubs_provided"]})
=> 
#<Foobara::Outcome:0x00007f9a989fe8b0
...
irb(main):002> outcome.success?
=> true
irb(main):003> outcome.result
=> 
#<FoobaraDemo::LoanOrigination::LoanFile::UnderwriterDecision:0x00007f9a981f24a0
 @attributes={decision: "denied", credit_score_used: 750, denied_reasons: ["insufficient_pay_stubs_provided"]},
 @mutable=true,
 @skip_validations=nil>
irb(main):004> underwriter_decision = outcome.result
=> 
#<FoobaraDemo::LoanOrigination::LoanFile::UnderwriterDecision:0x00007f9a981f24a0
...
irb(main):005> underwriter_decision.denied_reasons.first
=> "insufficient_pay_stubs_provided"
```

We could now let our original AgentBackedCommand call this new one we wrote just like any other command. 
This means we'd have one agent orchestrating another without even knowing that that's what its doing:

```ruby
module FoobaraDemo
  module LoanOrigination
    class ReviewLoanFile < Foobara::AgentBackedCommand
      add_inputs do
        loan_file LoanFile, :required
      end

      result LoanFile::UnderwriterDecision

      depends_on StartUnderwriterReview,
                 FindCreditPolicy,
                 DenyLoanFile,
                 ApproveLoanFile

      verbose
    end

    class ReviewAllLoanFilesNeedingReview < Foobara::AgentBackedCommand
      result do
        approved_count :integer, :required
        denied_count :integer, :required
      end
      depends_on FindALoanFileThatNeedsReview, ReviewLoanFile
      verbose
    end
  end
end

outcome = FoobaraDemo::LoanOrigination::ReviewAllLoanFilesNeedingReview.run

if outcome.success?
  result = outcome.result

  puts "Great success!!"
  puts "Approved: #{result[:approved_count]}"
  puts "Denied: #{result[:denied_count]}"
else
  warn "Error: #{outcome.errors_hash}"
end
```

Which gives the following output:

```
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ListCommands")
Foobara::Agent::ListCommands.run
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview")
FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview.run
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::ReviewLoanFile")
FoobaraDemo::LoanOrigination::ReviewLoanFile.run(loan_file: 79)
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ListCommands")
Foobara::Agent::ListCommands.run
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::StartUnderwriterReview")
FoobaraDemo::LoanOrigination::StartUnderwriterReview.run(loan_file: 79)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::FindCreditPolicy")
FoobaraDemo::LoanOrigination::FindCreditPolicy.run(credit_policy: 79)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::DenyLoanFile")
FoobaraDemo::LoanOrigination::DenyLoanFile.run(loan_file: 79, credit_score_used: 650, denied_reasons: ["low_credit_score"])
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ReviewLoanFileAgent::NotifyUserThatCurrentGoalHasBeenAccomplished")
Foobara::Agent::ReviewLoanFileAgent::NotifyUserThatCurrentGoalHasBeenAccomplished.run(result: {"decision" => "denied", "credit_score_used" => 650, "denied_reasons" => ["low_credit_score"]})
FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview.run
FoobaraDemo::LoanOrigination::ReviewLoanFile.run(loan_file: 80)
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ListCommands")
Foobara::Agent::ListCommands.run
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::StartUnderwriterReview")
FoobaraDemo::LoanOrigination::StartUnderwriterReview.run(loan_file: 80)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::FindCreditPolicy")
FoobaraDemo::LoanOrigination::FindCreditPolicy.run(credit_policy: 80)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::ApproveLoanFile")
FoobaraDemo::LoanOrigination::ApproveLoanFile.run(loan_file: 80, credit_score_used: 750)
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ReviewLoanFileAgent::NotifyUserThatCurrentGoalHasBeenAccomplished")
Foobara::Agent::ReviewLoanFileAgent::NotifyUserThatCurrentGoalHasBeenAccomplished.run(result: {"decision" => "approved", "credit_score_used" => 750})
FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview.run
FoobaraDemo::LoanOrigination::ReviewLoanFile.run(loan_file: 81)
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ListCommands")
Foobara::Agent::ListCommands.run
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::StartUnderwriterReview")
FoobaraDemo::LoanOrigination::StartUnderwriterReview.run(loan_file: 81)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::FindCreditPolicy")
FoobaraDemo::LoanOrigination::FindCreditPolicy.run(credit_policy: 81)
Foobara::Agent::DescribeCommand.run(command_name: "FoobaraDemo::LoanOrigination::ApproveLoanFile")
FoobaraDemo::LoanOrigination::ApproveLoanFile.run(loan_file: 81, credit_score_used: 750)
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ReviewLoanFileAgent::NotifyUserThatCurrentGoalHasBeenAccomplished")
Foobara::Agent::ReviewLoanFileAgent::NotifyUserThatCurrentGoalHasBeenAccomplished.run(result: {"decision" => "approved", "credit_score_used" => 750})
FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview.run
Foobara::Agent::DescribeCommand.run(command_name: "Foobara::Agent::ReviewAllLoanFilesNeedingReviewAgent::NotifyUserThatCurrentGoalHasBeenAccomplished")
Foobara::Agent::ReviewAllLoanFilesNeedingReviewAgent::NotifyUserThatCurrentGoalHasBeenAccomplished.run(approved_count: 2, denied_count: 1)
Great success!!
Approved: 2
Denied: 1
```

Here you can see two agents working together to solve the problem without either knowing it.

## Contributing

Helllllp! If this project seems interesting and you want to try using it or you want to help, please get in touch!
There's no shortage of work to do of any experience level.

Bug reports and pull requests are welcome on GitHub
at https://github.com/foobara/agent-backed-command

## License

This project is licensed under the MPL-2.0 license. Please see LICENSE.txt for more info.
