# frozen_string_literal: true

require_relative "lib/coro_ctx/version"

Gem::Specification.new do |spec|
  spec.name = "coro_ctx"
  spec.version = CoroCtx::VERSION
  spec.authors = ["nicholas a. evans"]
  spec.email = ["nicholas.evans@gmail.com"]

  spec.summary = "Context variables and coroutine scopes"
  spec.description = "coroutine context variables and scopes..."
  spec.homepage = "https://github.com/nevans/coro_ctx"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  exclusion_regex = %r{
    \A(?:
       (?:bin|test|spec|features)/
       | \.(?:git|travis|circleci)
       | appveyor
      )
  }x
  spec.files = Dir.chdir(File.expand_path(__dir__)) {
    `git ls-files -z`.split("\x0").grep_v(__FILE__).grep_v(exclusion_regex)
  }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) {|f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
