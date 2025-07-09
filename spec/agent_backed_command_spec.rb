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
        max_llm_calls_per_minute:
      }.tap do |h|
        unless pass_aggregates_to_llm.nil?
          h[:pass_aggregates_to_llm] = pass_aggregates_to_llm
        end

        unless result_entity_depth.nil?
          h[:result_entity_depth] = result_entity_depth
        end

        unless llm_model.nil?
          h[:llm_model] = llm_model
        end

        h[:verbose] = verbose unless verbose.nil?
      end
    }
  end
  let(:outcome) { command.run }
  let(:result) { outcome.result }
  let(:errors_hash) { outcome.errors_hash }
  let(:max_llm_calls_per_minute) { 100 }
  let(:verbose) { nil }
  let(:pass_aggregates_to_llm) { nil }
  let(:result_entity_depth) { nil }
  let(:llm_model) { nil }

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
      command_class.verbose verbose
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

    context "when not using a result type" do
      let(:command_class) do
        stub_class("FoobaraDemo::LoanOrigination::ReviewAllLoanFilesNeedingReview", described_class)
      end

      it "reviews all of the loan files needing review", vcr: { record: :none } do
        loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

        expect(loan_files.map(&:state)).to all eq(:needs_review)

        expect(outcome).to be_success
        expect(result).to be_nil

        loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

        expect(loan_files.map(&:state)).to contain_exactly(:drafting_docs, :denied, :denied)
      end
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

    context "with an AgentBackedCommand that takes inputs" do
      let(:command_class) do
        v = verbose

        stub_class("FoobaraDemo::LoanOrigination::ReviewLoanFile", described_class) do
          description "Checks the LoanFile against all requirements in its CreditPolicy. " \
                      "Denies the LoanFile that has any unsatisfied requirements."

          add_inputs do
            loan_file FoobaraDemo::LoanOrigination::LoanFile, :required
          end

          result FoobaraDemo::LoanOrigination::LoanFile::UnderwriterDecision

          depends_on FoobaraDemo::LoanOrigination::StartUnderwriterReview,
                     FoobaraDemo::LoanOrigination::FindCreditPolicy,
                     FoobaraDemo::LoanOrigination::DenyLoanFile,
                     FoobaraDemo::LoanOrigination::ApproveLoanFile

          verbose v
        end

        stub_class("FoobaraDemo::LoanOrigination::ReviewAllLoanFilesNeedingReview", described_class) do
          result do
            approved_count :integer, :required
            denied_count :integer, :required
          end
          depends_on FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview,
                     FoobaraDemo::LoanOrigination::ReviewLoanFile
          verbose v
        end
      end

      it "reviews all of the loan files needing review", vcr: { record: :none } do
        loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

        expect(loan_files.map(&:state)).to all eq(:needs_review)

        expect(outcome).to be_success
        expect(result.keys).to contain_exactly(:approved_count, :denied_count)
        expect(result[:approved_count]).to eq(1)
        expect(result[:denied_count]).to eq(2)

        loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

        expect(loan_files.map(&:state)).to contain_exactly(:drafting_docs, :denied, :denied)
      end
    end

    context "with pass_aggregates_to_llm and result_entity_depth options" do
      let(:pass_aggregates_to_llm) { true }
      let(:result_entity_depth) { Foobara::AssociationDepth::AGGREGATE }
      let(:llm_model) { "claude-sonnet-4-20250514" }

      let(:command_class) do
        stub_class("FoobaraDemo::LoanOrigination::ReviewAllLoanFilesNeedingReview", described_class) do
          description "Checks each LoanFile needing review against all requirements in its CreditPolicy. " \
                      "If any requirement is not satisfied, it will be denied. Otherwise, approved"

          result do
            approved [FoobaraDemo::LoanOrigination::LoanFile], :required
            denied [FoobaraDemo::LoanOrigination::LoanFile], :required
          end

          depends_on FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview,
                     FoobaraDemo::LoanOrigination::StartUnderwriterReview,
                     FoobaraDemo::LoanOrigination::DenyLoanFile,
                     FoobaraDemo::LoanOrigination::ApproveLoanFile
        end
      end

      it "reviews all of the loan files needing review", vcr: { record: :none } do
        loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

        expect(loan_files.map(&:state)).to all eq(:needs_review)

        expect(outcome).to be_success
        expect(result.keys).to contain_exactly(:approved, :denied)
        expect(result[:approved].size).to eq(1)
        expect(result[:approved].first.credit_policy.institution).to eq("Bank C")
        expect(result[:denied].size).to eq(2)
        expect(result[:denied].map).to all be_a(FoobaraDemo::LoanOrigination::LoanFile)

        loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

        expect(loan_files.map(&:state)).to contain_exactly(:drafting_docs, :denied, :denied)
      end

      context "with two agents one that requires inputs" do
        let(:pass_aggregates_to_llm) { nil }
        let(:result_entity_depth) { nil }
        let(:command_class) do
          v = verbose

          stub_class("FoobaraDemo::LoanOrigination::ReviewLoanFile", described_class) do
            description "Checks the LoanFile against all requirements in its CreditPolicy. " \
                        "Denies the LoanFile that has any unsatisfied requirements."

            add_inputs do
              loan_file FoobaraDemo::LoanOrigination::LoanFile, :required
            end

            result FoobaraDemo::LoanOrigination::LoanFile::UnderwriterDecision

            depends_on FoobaraDemo::LoanOrigination::StartUnderwriterReview,
                       FoobaraDemo::LoanOrigination::DenyLoanFile,
                       FoobaraDemo::LoanOrigination::ApproveLoanFile

            self.llm_model = "claude-opus-4-20250514"
            self.pass_aggregates_to_llm = true
            verbose v
          end

          stub_class("FoobaraDemo::LoanOrigination::ReviewAllLoanFilesNeedingReview", described_class) do
            result do
              approved [FoobaraDemo::LoanOrigination::LoanFile], :required
              denied [FoobaraDemo::LoanOrigination::LoanFile], :required
            end
            depends_on FoobaraDemo::LoanOrigination::FindALoanFileThatNeedsReview,
                       FoobaraDemo::LoanOrigination::ReviewLoanFile

            self.llm_model = "gpt-4o"
            self.pass_aggregates_to_llm = false
            self.result_entity_depth = Foobara::AssociationDepth::AGGREGATE
            verbose v
          end
        end

        it "reviews all of the loan files needing review", vcr: { record: :none } do
          loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

          expect(loan_files.map(&:state)).to all eq(:needs_review)

          expect(outcome).to be_success
          expect(result.keys).to contain_exactly(:approved, :denied)
          expect(result[:approved].size).to eq(1)
          expect(result[:approved].first.credit_policy.institution).to eq("Bank C")
          expect(result[:denied].size).to eq(2)
          expect(result[:denied].map).to all be_a(FoobaraDemo::LoanOrigination::LoanFile)

          loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

          expect(loan_files.map(&:state)).to contain_exactly(:drafting_docs, :denied, :denied)
        end
      end

      context "when using agent options instead of class methods" do
        let(:command_class) do
          stub_class("FoobaraDemo::LoanOrigination::ReviewLoanFile", described_class) do
            description "Checks the LoanFile against all requirements in its CreditPolicy. " \
                        "Denies the LoanFile that has any unsatisfied requirements."

            add_inputs do
              loan_file FoobaraDemo::LoanOrigination::LoanFile, :required
            end

            result FoobaraDemo::LoanOrigination::LoanFile::UnderwriterDecision

            depends_on FoobaraDemo::LoanOrigination::StartUnderwriterReview,
                       FoobaraDemo::LoanOrigination::DenyLoanFile,
                       FoobaraDemo::LoanOrigination::ApproveLoanFile
          end
        end

        it "can review the file even from the aggregate data", vcr: { record: :none } do
          loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!

          results = loan_files.map do |loan_file|
            FoobaraDemo::LoanOrigination::ReviewLoanFile.run!(
              loan_file: loan_file.id,
              agent_options: {
                pass_aggregates_to_llm: true,
                result_entity_depth: Foobara::AssociationDepth::AGGREGATE,
                verbose:,
                llm_model: "claude-opus-4-20250514"
              }
            )
          end

          expect(results.map(&:to_h)).to contain_exactly(
            { decision: "denied", credit_score_used: 650, denied_reasons: ["low_credit_score"] },
            { decision: "denied", credit_score_used: 750, denied_reasons: ["insufficient_pay_stubs_provided"] },
            { decision: "approved", credit_score_used: 750 }
          )

          loan_files = FoobaraDemo::LoanOrigination::FindAllLoanFiles.run!
          expect(loan_files.map(&:state)).to contain_exactly(:drafting_docs, :denied, :denied)
        end
      end
    end
  end
end
