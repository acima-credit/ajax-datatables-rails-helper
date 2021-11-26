# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

require 'rubocop/rake_task'
desc 'Runs rubocop with our custom settings'
RuboCop::RakeTask.new(:rubocop)
