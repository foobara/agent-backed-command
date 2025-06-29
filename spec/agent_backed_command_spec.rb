RSpec.describe Foobara::AgentBackedCommand do
  after do
    Foobara.reset_alls
    if Foobara::Agent.const_defined?(:ReviewAllLoanFilesNeedingReviewAgent)
      Foobara::Agent.send(:remove_const, :ReviewAllLoanFilesNeedingReviewAgent)
    end
  end

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
  let(:verbose) { false }

  context "when making an underwriting agent for the demo loan-origination domain" do
    let(:command_class) do
      stub_class("FoobaraDemo::LoanOrigination::ReviewAllLoanFilesNeedingReview", described_class) do
        description "Checks each LoanFile needing review against all requirements in its CreditPolicy. " \
                    "If any requirement is not satisfied, it will be denied. Otherwise, approved"

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

    context "when using message_to_user" do
      before do
        command_class.result do
          message_to_user :string, :required, "A message to the user about what was done."
        end
      end

      it "reviews all of the loan files needing review", vcr: { record: :none } do
        loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

        expect(loan_files.map(&:state)).to all eq(:needs_review)

        expect(outcome).to be_success
        expect(result[:message_to_user]).to be_a(String)

        loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

        expect(loan_files.map(&:state)).to contain_exactly(:drafting_docs, :denied, :denied)
      end

      context "when also using result_data" do
        before do
          command_class.result do
            message_to_user :string
            result_data do
              approved_count :integer, :required
              denied_count :integer, :required
            end
          end
        end

        it "reviews all of the loan files needing review", vcr: { record: :none } do
          loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

          expect(loan_files.map(&:state)).to all eq(:needs_review)

          expect(outcome).to be_success
          expect(result[:message_to_user]).to be_a(String)
          expect(result[:result_data]).to eq(approved_count: 1, denied_count: 2)

          loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

          expect(loan_files.map(&:state)).to contain_exactly(:drafting_docs, :denied, :denied)
        end
      end
    end

    context "when returning attributes" do
      before do
        command_class.result do
          approved_count :integer, :required
          denied_count :integer, :required
        end
      end

      it "reviews all of the loan files needing review", vcr: { record: :none } do
        loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

        expect(loan_files.map(&:state)).to all eq(:needs_review)

        expect(outcome).to be_success
        expect(result).to eq(approved_count: 1, denied_count: 2)

        loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

        expect(loan_files.map(&:state)).to contain_exactly(:drafting_docs, :denied, :denied)
      end

      context "when including message_to_user" do
        before do
          command_class.result do
            message_to_user :string
            approved_count :integer, :required
            denied_count :integer, :required
          end
        end

        it "reviews all of the loan files needing review", vcr: { record: :none } do
          loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

          expect(loan_files.map(&:state)).to all eq(:needs_review)

          expect(outcome).to be_success
          expect(result.keys).to contain_exactly(:message_to_user, :approved_count, :denied_count)
          expect(result[:approved_count]).to eq(1)
          expect(result[:denied_count]).to eq(2)
          expect(result[:message_to_user]).to be_a(String)

          loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

          expect(loan_files.map(&:state)).to contain_exactly(:drafting_docs, :denied, :denied)
        end
      end
    end
  end
end
