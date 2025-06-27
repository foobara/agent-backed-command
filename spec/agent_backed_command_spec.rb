require "foobara_demo/loan_origination"

RSpec.describe Foobara::AgentBackedCommand do
  after { Foobara.reset_alls }

  before do
    crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    Foobara::Persistence.default_crud_driver = crud_driver
  end

  let(:command) { command_class.new(inputs) }
  let(:inputs) do
    {
      agent_options: {
        verbose:,
        max_llm_calls_per_minute:
      }
    }
  end
  let(:outcome) { command.run }
  let(:result) { outcome.result }
  let(:errors_hash) { outcome.errors_hash }
  let(:max_llm_calls_per_minute) { 100 }
  # let(:verbose) { false }
  let(:verbose) { true }

  context "when making an underwriting agent for the demo loan-origination domain" do
    let(:command_class) do
      stub_class("FoobaraDemo::LoanOrigination::ReviewAllLoanFilesNeedingReview", described_class) do
        description "For each loan file needing review, " \
                    "it will approve or deny the loan file based on its credit policy rules."

        result :array, element_type_declaration: {
          type: :attributes,
          element_type_declarations: {
            applicant_name: :string,
            underwriter_decision: :"FoobaraDemo::LoanOrigination::decision"
          },
          required: [:applicant_name, :underwriter_decision]
        }

        # self.llm_model = "gpt-4o"
        self.llm_model = "claude-opus-4-20250514"
        # self.llm_model = "claude-3-7-sonnet-20250219"
      end
    end
    # TODO: uncomment this when re-recording cassettes if needed
    # let(:max_llm_calls_per_minute) { 4 }

    before do
      FoobaraDemo::LoanOrigination::Demo::PrepareDemoRecords.run!
    end

    it "reviews all of the loan files needing review", vcr: { record: :none } do
      loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

      expect(loan_files.map(&:state)).to all eq(:needs_review)

      expect(outcome).to be_success
      expect(result).to contain_exactly(
        { applicant_name: "Barbara", underwriter_decision: "denied" },
        { applicant_name: "Basil", underwriter_decision: "denied" },
        { applicant_name: "Fumiko", underwriter_decision: "approved" }
      )

      loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

      expect(loan_files.map(&:state)).to contain_exactly(:drafting_docs, :denied, :denied)
    end
  end
end
