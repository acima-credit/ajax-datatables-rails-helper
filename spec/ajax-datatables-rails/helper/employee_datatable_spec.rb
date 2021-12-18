# frozen_string_literal: true

require 'spec_helper'

class EmployeeDatatable < AjaxDatatablesRails::ActiveRecord
  include AjaxDatatablesRails::Helper::ExtendedDatatable

  set_model :employee

  column 'id', :orderable, title: 'ID', search: { cond: :eq }
  column 'username', :orderable, title: 'Username', search: { cond: :like }
  column 'full_name', :orderable, title: 'Name', search: { cond: :like }
  column 'status', :orderable, title: 'Status', search: { values: model::STATUS.values }, display: { align: :center }
  column 'age', :orderable, title: 'Age', search: { cond: :eq }
  column 'hired_at', :orderable
  column 'created_at', :orderable, search: { cond: :date_range, delimiter: '|' }, display: { render: 'DTUtils.displayTimestamp' }
  column 'comment', display: :none
  rel_column 'company', :name, title: 'Company'
  rel_column 'company', :category, title: 'Category', display: :none

  action_link :addresses,
              title: 'Addresses',
              url: '/admin/employee/addressed/:id'

  def base_scope
    super.where('age < ?', 80)
  end

  # def get_raw_records
  #   base_scope.joins(:company).references(:company).distinct
  # end
end

RSpec.describe EmployeeDatatable, type: :datatable do
  let(:statuses) { model::STATUS.values }

  describe 'instance' do
    describe '#columns' do
      let(:column_types) { subject.columns.values.map { |x| x.class.name }.uniq.sort }
      let(:values) { subject.columns.transform_values(&:to_hash) }
      let(:expected) do
        {
          id: { field: 'id', title: 'ID', source: "#{model.name}.id",
                orderable: true, searchable: true, search: { cond: :eq }, display: nil },
          username: { field: 'username', title: 'Username', source: "#{model.name}.username",
                      orderable: true, searchable: true, search: { cond: :like }, display: nil },
          full_name: { field: 'full_name', title: 'Name', source: "#{model.name}.full_name",
                       orderable: true, searchable: true, search: { cond: :like }, display: nil },
          status: { field: 'status', title: 'Status', source: "#{model.name}.status",
                    orderable: true, searchable: true, search: { values: statuses, cond: :string_eq }, display: { align: :center } },
          age: { field: 'age', title: 'Age', source: "#{model.name}.age",
                 orderable: true, searchable: true, search: { cond: :eq }, display: nil },
          hired_at: { field: 'hired_at', title: 'Hired', source: "#{model.name}.hired_at",
                      orderable: true, searchable: false, search: nil, display: nil },
          created_at: { field: 'created_at', title: 'Created', source: "#{model.name}.created_at",
                        orderable: true, searchable: true, search: { cond: :date_range, delimiter: '|' },
                        display: { render: 'DTUtils.displayTimestamp' } },
          comment: { field: 'comment', title: 'Comment', source: "#{model.name}.comment",
                     orderable: false, searchable: false, search: nil, display: :none },
          company_name: { field: 'company.name', title: 'Company', source: 'Company.name', relation: 'company',
                          orderable: false, searchable: false, search: nil, display: nil },
          company_category: { field: 'company.category', title: 'Category', source: 'Company.category', relation: 'company',
                              orderable: false, searchable: false, search: nil, display: :none },
          actions: { field: nil, title: 'Actions', source: nil,
                     orderable: false, searchable: false, search: nil, display: nil,
                     links: { addresses: { title: 'Addresses', url: '/admin/employee/addressed/:id' } } }
        }
      end

      it('types') do
        expect(column_types).to eq %w[
          AjaxDatatablesRails::Helper::ActionColumn
          AjaxDatatablesRails::Helper::Column
          AjaxDatatablesRails::Helper::RelatedColumn
        ]
      end
      it('definition') { expect(values).to eq expected }
    end

    describe '#view_columns' do
      let(:expected) do
        {
          id: { source: "#{model.name}.id", title: 'ID', orderable: true, searchable: true, cond: :eq },
          username: { source: "#{model.name}.username", title: 'Username', orderable: true, searchable: true, cond: :like },
          full_name: { source: "#{model.name}.full_name", title: 'Name', orderable: true, searchable: true, cond: :like },
          status: { source: "#{model.name}.status", title: 'Status', orderable: true, searchable: true, cond: :string_eq },
          age: { source: "#{model.name}.age", title: 'Age', orderable: true, searchable: true, cond: :eq },
          hired_at: { source: "#{model.name}.hired_at", title: 'Hired', orderable: true, searchable: false },
          created_at: { source: "#{model.name}.created_at", title: 'Created', orderable: true, searchable: true, cond: :date_range, delimiter: '|' },
          comment: { source: "#{model.name}.comment", title: 'Comment', orderable: false, searchable: false },
          company_name: { source: 'Company.name', title: 'Company', orderable: false, searchable: false },
          company_category: { source: 'Company.category', title: 'Category', orderable: false, searchable: false },
          actions: { orderable: false, searchable: false, source: nil, title: 'Actions' }
        }
      end

      it('definition') { expect(subject.view_columns).to eq expected }
    end

    describe '#js_columns' do
      let(:expected) do
        [
          { title: 'ID', orderable: true, searchable: true, data: 'id' },
          { title: 'Username', orderable: true, searchable: true, data: 'username' },
          { title: 'Name', orderable: true, searchable: true, data: 'full_name' },
          { title: 'Status', orderable: true, searchable: true, data: 'status', className: 'text-center' },
          { title: 'Age', orderable: true, searchable: true, data: 'age' },
          { title: 'Hired', orderable: true, searchable: false, data: 'hired_at' },
          { title: 'Created', orderable: true, searchable: true, data: 'created_at', render: js('DTUtils.displayTimestamp') },
          { title: 'Company', orderable: false, searchable: false, data: 'company_name' },
          { title: 'Actions', orderable: false, searchable: false, data: nil }
        ]
      end

      let(:expected_json) do
        <<~JAVASCRIPT.chomp
          [
            {
              "title": "ID",
              "orderable": true,
              "searchable": true,
              "data": "id"
            },
            {
              "title": "Username",
              "orderable": true,
              "searchable": true,
              "data": "username"
            },
            {
              "title": "Name",
              "orderable": true,
              "searchable": true,
              "data": "full_name"
            },
            {
              "title": "Status",
              "orderable": true,
              "searchable": true,
              "data": "status",
              "className": "text-center"
            },
            {
              "title": "Age",
              "orderable": true,
              "searchable": true,
              "data": "age"
            },
            {
              "title": "Hired",
              "orderable": true,
              "searchable": false,
              "data": "hired_at"
            },
            {
              "title": "Created",
              "orderable": true,
              "searchable": true,
              "data": "created_at",
              "render": DTUtils.displayTimestamp
            },
            {
              "title": "Company",
              "orderable": false,
              "searchable": false,
              "data": "company_name"
            },
            {
              "title": "Actions",
              "orderable": false,
              "searchable": false,
              "data": null
            }
          ]
        JAVASCRIPT
      end

      it('definition') { expect(subject.js_columns.inspect).to eq expected.inspect }
      it('json') { expect(JSON.pretty_generate(subject.js_columns)).to eq expected_json }
    end

    describe '#js_searches' do
      let(:expected) do
        [
          { field: 'id', title: 'ID', type: 'text' },
          { field: 'username', title: 'Username', type: 'text' },
          { field: 'full_name', title: 'Name', type: 'text' },
          { field: 'status', title: 'Status', type: 'select', values: statuses },
          { field: 'age', title: 'Age', type: 'text' },
          { field: 'hired_at', title: 'Hired', type: 'none' },
          { field: 'created_at', title: 'Created', type: 'date_range', delimiter: '|' },
          { field: 'company_name', title: 'Company', type: 'none' },
          { field: nil, title: 'Actions', type: 'none' }
        ]
      end

      it('definition') { expect(subject.js_searches).to eq expected }

      context 'with query params' do
        let(:params) { { username: 'emp3', status: 'active', unknown: 'some.value' } }
        let(:expected) do
          [
            { field: 'id', title: 'ID', type: 'text' },
            { field: 'username', title: 'Username', type: 'text', value: 'emp3' },
            { field: 'full_name', title: 'Name', type: 'text' },
            { field: 'status', title: 'Status', type: 'select', value: 'active', values: statuses },
            { field: 'age', title: 'Age', type: 'text' },
            { field: 'hired_at', title: 'Hired', type: 'none' },
            { field: 'created_at', title: 'Created', type: 'date_range', delimiter: '|' },
            { field: 'company_name', title: 'Company', type: 'none' },
            { field: nil, title: 'Actions', type: 'none' }
          ]
        end

        it('definition') { expect(subject.js_searches).to eq expected }
      end
    end

    describe '#get_raw_records' do
      let(:sql_query) do
        <<~SQL.squish
          SELECT "employees".*
          FROM "employees"
          WHERE (age < 80)
        SQL
      end
      let(:result) { subject.get_raw_records }
      it('to_sql') { expect(result.to_sql).to eq sql_query }
      it('definition') { expect(result).to be_a ActiveRecord::Relation }
    end

    describe '#retrieve_records' do
      context 'basic' do
        let(:params) { build_params }
        let(:sql_query) do
          <<~SQL.squish
            SELECT "employees".*
            FROM "employees" WHERE (age < 80)
            ORDER BY employees.id ASC IS NULL
            LIMIT 3
            OFFSET 0
          SQL
        end
        let(:result) { subject.send :retrieve_records }
        it('to_sql') { expect(result.to_sql).to eq sql_query }
        it('definition') { expect(result).to be_a ActiveRecord::Relation }
      end
      context 'sorted' do
        let(:params) { build_params sort_col: 'username', sort_dir: 'desc' }
        let(:sql_query) do
          <<~SQL.squish
            SELECT "employees".*
            FROM "employees" WHERE (age < 80)
            ORDER BY employees.username DESC IS NULL
            LIMIT 3
            OFFSET 0
          SQL
        end
        let(:result) { subject.send :retrieve_records }
        it('to_sql') { expect(result.to_sql).to eq sql_query }
        it('definition') { expect(result).to be_a ActiveRecord::Relation }
      end
    end

    describe '#data' do
      let!(:items) { all_employees }
      let(:params) { { order: { '0' => { 'column' => '1', 'dir' => 'asc' } }, start: '1', length: '2' } }
      let(:exp_result) { build_exp_items 1, 2 }

      it('result') { expect(subject.data).to eq exp_result }
    end

    describe '#build_record_entry' do
      let(:row) { emp1 }
      let(:exp_result) do
        {
          id: row.id,
          username: 'emp1',
          full_name: 'Employee Uno',
          status: 'active',
          age: 25,
          hired_at: date1,
          created_at: row.created_at,
          comment: row.comment,
          company_name: cmp1.name,
          company_category: cmp1.category,
          DT_RowId: row.id
        }
      end

      it('result') { expect(subject.build_record_entry(row)).to eq exp_result }
    end

    describe '#dom_id' do
      it('result') { expect(subject.dom_id).to eq 'employee-datatable' }
    end
  end
end
