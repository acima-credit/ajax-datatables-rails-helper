# frozen_string_literal: true

require 'bundler/setup'

require 'logger'
require 'active_record'
require 'action_controller/metal/strong_parameters'
require 'action_pack'
require 'ajax-datatables-rails'
require 'ajax-datatables-rails-helper'
require 'fatherly_advice'
require 'timecop'
require 'rspec/json_expectations'
require 'rspec/core/shared_context'

FatherlyAdvice.ext :enums

ActiveRecord::Base.logger = Logger.new($stderr).tap { |x| x.level = 1 }

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

ActiveRecord::Schema.define do
  create_table :companies do |table|
    table.column :name, :string
    table.column :category, :string
    table.timestamps
  end
  create_table :employees do |table|
    table.column :company_id, :integer
    table.column :username, :string
    table.column :full_name, :string
    table.column :status, :string
    table.column :age, :integer
    table.column :hired_at, :datetime
    table.column :comment, :string
    table.timestamps
  end
  create_table :employee_addresses do |table|
    table.column :employee_id, :integer
    table.column :description, :string
    table.column :street, :string
    table.column :city, :string
    table.column :state, :datetime
    table.column :zip_code, :integer
    table.timestamps
  end
end

class Company < ActiveRecord::Base
  has_many :employees
end

class Employee < ActiveRecord::Base
  STATUS = Enums.build :active, :inactive
  belongs_to :company
  has_many :addresses, class_name: 'EmployeeAddress'
end

class EmployeeAddress < ActiveRecord::Base
  DESCRIPTIONS = Enums.build :home, :work
  belongs_to :employee
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

  let(:datatable) { described_class }
  let(:model) { described_class.model }
  let(:table_name) { model.table_name }

  let(:params) { {} }
  let(:conv_params) { ActionController::Parameters.new params }
  let(:options) { {} }

  let(:subject) { described_class.new conv_params, options }

  def js(value)
    AjaxDatatablesRails::Helper::JsValue.new value
  end

  def model_field_names
    {
      employee: %i[username full_name status age hired_at created_at company comment],
      company: %i[name category]
    }
  end

  def create(model, *args, **opts)
    fields = {}
    args.each_with_index do |v, idx|
      k = model_field_names[model][idx]
      fields[k] = v
    end
    fields.update(opts)

    model = model.to_s.classify.constantize if model.is_a?(Symbol)
    model.create fields
  end

  def create_many(model, qty, *args, **opts)
    1.upto(qty).map do |x|
      opts.update yield(x) if block_given?
      create model, *args, **opts
    end
  end

  def build_exp_items(start_idx = 0, qty = items.size)
    items[start_idx, qty].map { |x| described_class.build_record_entry x }
  end

  let(:date1) { Time.new 2020, 1, 1, 10, 15 }
  let(:date2) { Time.new 2020, 3, 15, 11, 15 }
  let(:date3) { Time.new 2021, 6, 15, 12, 15 }

  let!(:cmp1) { create :company, 'First Company', 'shoes' }
  let!(:cmp2) { create :company, 'Second Company', 'sandals' }

  let!(:emp1) { create :employee, 'emp1', 'Employee Uno', 'active', 25, date1, date1, cmp1, 'emp01' }
  let!(:emp2) { create :employee, 'emp2', 'Employee Dos', 'inactive', 19, date1, date1, cmp2, 'emp02' }
  let!(:emp3) { create :employee, 'emp3', 'Employee Tres', 'active', 32, date2, date2, cmp1, 'emp03' }
  let!(:emp4) { create :employee, 'emp4', 'Employee Cuatro', 'inactive', 23, date2, date2, cmp2, 'emp04' }
  let!(:emp5) { create :employee, 'emp5', 'Employee Cinco', 'active', 45, date2, date2, cmp1, 'emp05' }
  let!(:emp6) { create :employee, 'emp6', 'Employee Seis', 'active', 85, date2, date2, cmp1, 'emp06' }

  let(:first_employees) { [emp1, emp2] }
  let(:second_employees) { [emp3, emp4, emp5, emp6] }
  let(:all_employees) { first_employees + second_employees }

  def build_params(start: 0, length: 3, sort_dir: 'asc', sort_col: 'id', sort_idx: 0, searches: {}, extras: {})
    columns = datatable.columns.each_with_index.each_with_object({}) do |((name, col), idx), hsh|
      sort_idx = idx if sort_col && sort_col.to_s == name.to_s
      hsh[idx.to_s] = {
        data: name.to_s,
        name: '',
        searchable: col.searchable,
        orderable: col.orderable,
        search: {
          value: searches.fetch(name, ''),
          regex: false
        }
      }
      hsh[idx.to_s][:data] = '' if name.to_s == 'actions'
    end
    {
      draw: 1,
      columns: columns,
      order: { 0 => { column: sort_idx.to_s, dir: sort_dir.to_s } },
      start: start.to_s,
      length: length.to_s,
      search: { value: '', regex: false },
      _: Time.current.to_i
    }.update(extras).deep_stringify_keys
  end
end

RSpec.configure do |config|
  config.include DatatablesHelpers, type: :datatable
  config.after { described_class.model.delete_all if described_class.respond_to?(:model) }
  # timecop
  config.before(:each, past_time: true) { Timecop.freeze date1 }
  config.before(:each, middle_time: true) { Timecop.freeze date2 }
  config.before(:each, future_time: true) { Timecop.freeze date3 }
end
