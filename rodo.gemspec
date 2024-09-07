# frozen_string_literal: true

require_relative "lib/rodo/version"

Gem::Specification.new do |spec|
  spec.name          = "rodo"
  spec.version       = Rodo::VERSION
  spec.authors       = ["Christopher Oezbek"]
  spec.email         = ["c.oezbek@gmail.com"]
  spec.licenses      = ['GPL-3.0-or-later']

  spec.summary       = "Rodo is terminal-based todo manager"
  spec.description   = "Rodo is terminal-based todo manager written in Ruby with a inbox-zero mentality."
  spec.homepage      = "https://github.com/coezbek/rodo"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["allowed_push_host"] = 'https://rubygems.org'

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/coezbek/rodo"
  spec.metadata["changelog_uri"] = "https://github.com/coezbek/rodo/plan.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "curses", "~> 1.4"
  spec.add_dependency "warning", "~> 1.0"
  spec.add_dependency "reverse_markdown", "~> 2.0" # Used for reverse markdown parsing
  spec.add_dependency "rrule", "~> 0.6"
  spec.add_dependency "redcarpet", "~> 3.6" # Used for reverse markdown parsing
  spec.add_dependency "timecop", "~> 0.9.10" # For testing time-dependent code

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.10"
end
