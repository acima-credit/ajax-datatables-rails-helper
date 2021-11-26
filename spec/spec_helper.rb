# frozen_string_literal: true

require 'bundler/setup'

require 'logger'
require 'active_record'
require 'action_controller/metal/strong_parameters'
require 'action_pack'
require 'ajax-datatables-rails'
require 'ajax-datatables-rails-helper'
require 'fatherly_advice'
require 'rspec/json_expectations'
require 'rspec/core/shared_context'

FatherlyAdvice.ext :enums

ActiveRecord::Base.logger = Logger.new($stderr).tap { |x| x.level = 1 }

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

ActiveRecord::Schema.define do
  create_table :employees do |table|
    table.column :username, :string
    table.column :full_name, :string
    table.column :status, :string
    table.column :age, :integer
    table.column :hired_at, :datetime
    table.timestamps
  end
end

class Employee < ActiveRecord::Base
  STATUS = Enums.build :active, :inactive
end

RSpec.configure do |config|
  config.default_formatter = :documentation if ENV['PRETTY']
  config.filter_run focus: true if ENV['FOCUS'].to_s == 'true'
  config.filter_run focus2: true if ENV['FOCUS2'].to_s == 'true'
  config.run_all_when_everything_filtered = true
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.example_status_persistence_file_path = '.rspec_status'
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.profile_examples = 3
  config.order = :random
  Kernel.srand config.seed
end

module DatatablesHelpers
  extend RSpec::Core::SharedContext

  let(:model) { described_class.model }

  let(:params) { {} }
  let(:conv_params) { ActionController::Parameters.new params }
  let(:options) { {} }

  let(:subject) { described_class.new conv_params, options }

  def create(opts = {})
    model.create opts
  end

  def create_many(qty, opts = {})
    1.upto(qty).map do |x|
      opts.update yield(x) if block_given?
      create(opts)
    end
  end

  def build_exp_items(start_idx = 0, qty = items.size)
    items[start_idx, qty].map { |x| described_class.build_record_entry x }
  end

  let(:date1) { Time.new 2020, 1, 1, 10, 15 }
  let(:date2) { Time.new 2020, 3, 15, 11, 15 }
  let(:emp1) { create username: 'emp1', full_name: 'Employee Uno', status: 'active', age: 25, hired_at: date1, created_at: date1 }
  let(:emp2) { create username: 'emp2', full_name: 'Employee Dos', status: 'inactive', age: 19, hired_at: date1, created_at: date1 }
  let(:emp3) { create username: 'emp3', full_name: 'Employee Tres', status: 'active', age: 32, hired_at: date2, created_at: date2 }
  let(:emp4) { create username: 'emp4', full_name: 'Employee Cuatro', status: 'inactive', age: 23, hired_at: date2, created_at: date2 }
  let(:emp5) { create username: 'emp5', full_name: 'Employee Cinco', status: 'active', age: 45, hired_at: date2, created_at: date2 }
  let(:first_employees) { [emp1, emp2] }
  let(:second_employees) { [emp3, emp4, emp5] }
  let(:all_employees) { first_employees + second_employees }
end

RSpec.configure do |config|
  config.include DatatablesHelpers, type: :datatable
  config.after { described_class.model.delete_all if described_class.respond_to?(:model) }
end
