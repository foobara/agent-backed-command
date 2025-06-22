RSpec.describe Foobara::AgentBackedCommandVersion do
  it "has a version number" do
    expect(Foobara::AgentBackedCommandVersion::VERSION).to_not be_nil
  end
end
