require_relative "version"

Gem::Specification.new do |spec|
  spec.name = "foobara-agent-backed-command"
  spec.version = Foobara::AgentBackedCommandVersion::VERSION
  spec.authors = ["Miles Georgi"]
  spec.email = ["azimux@gmail.com"]

  spec.summary = "Provides a way to create a command without an execute method that is instead executed by a Foobara::Agent"
  spec.homepage = "https://github.com/foobara/agent-backed-command"
  spec.license = "MPL-2.0"
  spec.required_ruby_version = Foobara::AgentBackedCommandVersion::MINIMUM_RUBY_VERSION

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "src/**/*",
    "LICENSE*.txt",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.add_dependency "foobara-agent", ">= 0.0.1", "< 2.0.0"

  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
