# frozen_string_literal: true

require_relative 'lib/ajax-datatables-rails/helper/version'

Gem::Specification.new do |spec|
  spec.name          = 'ajax-datatables-rails-helper'
  spec.version       = AjaxDatatablesRails::Helper::VERSION
  spec.authors       = ['Adrian Madrid']
  spec.email         = ['aemadrid@gmail.com']

  spec.summary       = "A gem that enriches Ajax datatables"
  spec.description   = spec.summary
  # spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
