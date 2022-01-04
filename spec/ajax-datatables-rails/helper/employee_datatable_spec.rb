# frozen_string_literal: true

require 'spec_helper'

class EmployeeDatatable < AjaxDatatablesRails::ActiveRecord
  include AjaxDatatablesRails::Helper::ExtendedDatatable

  module AddressesCountDisplayMixin
    def self.call(row)
      row.addresses.map(&:description).sort.reverse.join('|')
    end
  end

  self.db_adapter = :postgresql
  set_model :employee

  column 'id', :orderable, title: 'ID', search: { cond: :eq }
  column 'username', :orderable, title: 'Username', search: { cond: :like }
  column 'full_name', :orderable, title: 'Name', search: { cond: :like }
  column 'status', :orderable, title: 'Status', search: { values: model::STATUS.values }, display: { align: :center }
  column 'age', :orderable, title: 'Age', search: { cond: :eq }
  column 'hired_at', :orderable
  column 'created_at', :orderable,
         search: { cond: :date_range, delimiter: '|', default: :today, values: %w[today yesterday this_week last_week] },
         display: { render: 'DTUtils.displayTimestamp' }
  column 'comment', display: :none
  rel_column 'company', :name, title: 'Company'
  rel_column 'company', :category, title: 'Category', display: :none

  dummy_column 'addresses_count',
               title: 'Addresses',
               display: { align: :center },
               build: AddressesCountDisplayMixin

  action_link :addresses,
              title: 'Addresses',
              url: '/admin/employee/addressed/:id'

  def base_scope
    super.where('age < ?', 80)
  end

  after_each :data, :split_address
  after_each(:data) { |row| row[:addresses_count] = row[:addresses_count].map(&:capitalize) }
  after :data, :sort_data_addresses

  def split_address(row)
    row[:addresses_count] = row[:addresses_count].split('|')
  end

  def sort_data_addresses(rows)
    rows.map do |row|
      row[:addresses_count] = row[:addresses_count].join(', ')
    end
  end
end

RSpec.describe EmployeeDatatable, :middle_time, type: :datatable do
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
                        orderable: true, searchable: true,
                        search: { cond: :date_range, delimiter: '|', default: :today, values: %w[today yesterday this_week last_week] },
                        display: { render: 'DTUtils.displayTimestamp' } },
          comment: { field: 'comment', title: 'Comment', source: "#{model.name}.comment",
                     orderable: false, searchable: false, search: nil, display: :none },
          company_name: { field: 'company.name', title: 'Company', source: 'Company.name', relation: 'company',
                          orderable: false, searchable: false, search: nil, display: nil },
          company_category: { field: 'company.category', title: 'Category', source: 'Company.category', relation: 'company',
                              orderable: false, searchable: false, search: nil, display: :none },
          addresses_count: {
            field: nil, title: 'Addresses', source: nil, build: described_class::AddressesCountDisplayMixin, default: nil,
            orderable: false, searchable: false, search: nil, display: { align: :center }
          },
          actions: { field: nil, title: 'Actions', source: nil,
                     orderable: false, searchable: false, search: nil, display: nil,
                     links: { addresses: { name: 'addresses', title: 'Addresses', url: '/admin/employee/addressed/:id' } } }
        }
      end

      it('types') do
        expect(column_types).to eq %w[
          AjaxDatatablesRails::Helper::ActionColumn
          AjaxDatatablesRails::Helper::Column
          AjaxDatatablesRails::Helper::DummyColumn
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
          addresses_count: { source: nil, title: 'Addresses', orderable: false, searchable: false },
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
          { title: 'Addresses', orderable: false, searchable: false, data: nil, className: 'text-center' },
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
              "title": "Addresses",
              "orderable": false,
              "searchable": false,
              "data": null,
              "className": "text-center"
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
          { field: 'created_at', title: 'Created', type: 'date_range', delimiter: '|', values: %w[today yesterday this_week last_week] },
          { field: 'company_name', title: 'Company', type: 'none' },
          { field: nil, title: 'Addresses', type: 'none' },
          { field: nil, title: 'Actions', type: 'none' }
        ]
      end

      it('definition') { expect(subject.js_searches).to eq expected }

      context 'with query params' do
        let(:params) { build_params extras: { username: 'emp3', status: 'active', unknown: 'some.value', created_at: 'yesterday' } }
        let(:expected) do
          [
            { field: 'id', title: 'ID', type: 'text' },
            { field: 'username', title: 'Username', type: 'text', value: 'emp3' },
            { field: 'full_name', title: 'Name', type: 'text' },
            { field: 'status', title: 'Status', type: 'select', value: 'active', values: statuses },
            { field: 'age', title: 'Age', type: 'text' },
            { field: 'hired_at', title: 'Hired', type: 'none' },
            { field: 'created_at', title: 'Created', type: 'date_range', delimiter: '|', value: 'yesterday', values: %w[today yesterday this_week last_week] },
            { field: 'company_name', title: 'Company', type: 'none' },
            { field: nil, title: 'Addresses', type: 'none' },
            { field: nil, title: 'Actions', type: 'none' }
          ]
        end

        it('definition') { expect(subject.js_searches).to eq expected }
      end
    end

    describe '#get_raw_records' do
      let(:sql_query) do
        <<~SQL.squish
          SELECT
          "employees"."id" AS t0_r0,
          "employees"."company_id" AS t0_r1,
          "employees"."username" AS t0_r2,
          "employees"."full_name" AS t0_r3,
          "employees"."status" AS t0_r4,
          "employees"."age" AS t0_r5, "employees"."hired_at" AS t0_r6,
          "employees"."comment" AS t0_r7,
          "employees"."created_at" AS t0_r8,
          "employees"."updated_at" AS t0_r9,
          "companies"."id" AS t1_r0,
          "companies"."name" AS t1_r1,
          "companies"."category" AS t1_r2,
          "companies"."created_at" AS t1_r3,
          "companies"."updated_at" AS t1_r4
          FROM "employees"
          LEFT OUTER JOIN "companies" ON "companies"."id" = "employees"."company_id"
          WHERE (age < 80)
        SQL
      end
      let(:result) { subject.get_raw_records }
      it('to_sql') { expect(result.to_sql).to eq sql_query }
      it('definition') { expect(result).to be_a ActiveRecord::Relation }
    end

    describe '#retrieve_records' do
      let(:result) { subject.send :retrieve_records }
      context 'basic' do
        let(:params) { build_params }
        let(:sql_query) do
          <<~SQL.squish
            SELECT
            "employees"."id" AS t0_r0,
            "employees"."company_id" AS t0_r1,
            "employees"."username" AS t0_r2,
            "employees"."full_name" AS t0_r3,
            "employees"."status" AS t0_r4,
            "employees"."age" AS t0_r5, "employees"."hired_at" AS t0_r6,
            "employees"."comment" AS t0_r7,
            "employees"."created_at" AS t0_r8,
            "employees"."updated_at" AS t0_r9,
            "companies"."id" AS t1_r0,
            "companies"."name" AS t1_r1,
            "companies"."category" AS t1_r2,
            "companies"."created_at" AS t1_r3,
            "companies"."updated_at" AS t1_r4
            FROM "employees"
            LEFT OUTER JOIN "companies" ON "companies"."id" = "employees"."company_id"
            WHERE (age < 80)
            AND "employees"."created_at" BETWEEN '2020-03-15 06:00:00' AND '2020-03-16 05:59:59'
            ORDER BY employees.id ASC NULLS LAST
            LIMIT 3
            OFFSET 0
          SQL
        end
        it('to_sql') { expect(result.to_sql).to eq sql_query }
        it('definition') { expect(result).to be_a ActiveRecord::Relation }
      end
      context 'sorted' do
        let(:params) { build_params sort_col: 'username', sort_dir: 'desc' }
        let(:sql_query) do
          <<~SQL.squish
            SELECT
            "employees"."id" AS t0_r0,
            "employees"."company_id" AS t0_r1,
            "employees"."username" AS t0_r2,
            "employees"."full_name" AS t0_r3,
            "employees"."status" AS t0_r4,
            "employees"."age" AS t0_r5, "employees"."hired_at" AS t0_r6,
            "employees"."comment" AS t0_r7,
            "employees"."created_at" AS t0_r8,
            "employees"."updated_at" AS t0_r9,
            "companies"."id" AS t1_r0,
            "companies"."name" AS t1_r1,
            "companies"."category" AS t1_r2,
            "companies"."created_at" AS t1_r3,
            "companies"."updated_at" AS t1_r4
            FROM "employees"
            LEFT OUTER JOIN "companies" ON "companies"."id" = "employees"."company_id"
            WHERE (age < 80)
            AND "employees"."created_at" BETWEEN '2020-03-15 06:00:00' AND '2020-03-16 05:59:59'
            ORDER BY employees.username DESC NULLS LAST
            LIMIT 3
            OFFSET 0
          SQL
        end
        it('to_sql') { expect(result.to_sql).to eq sql_query }
        it('definition') { expect(result).to be_a ActiveRecord::Relation }
      end
      context 'search created_at' do
        let(:params) { build_params searches: { created_at: created_at } }
        let(:sql_query) do
          <<~SQL.squish
            SELECT
            "employees"."id" AS t0_r0,
            "employees"."company_id" AS t0_r1,
            "employees"."username" AS t0_r2,
            "employees"."full_name" AS t0_r3,
            "employees"."status" AS t0_r4,
            "employees"."age" AS t0_r5, "employees"."hired_at" AS t0_r6,
            "employees"."comment" AS t0_r7,
            "employees"."created_at" AS t0_r8,
            "employees"."updated_at" AS t0_r9,
            "companies"."id" AS t1_r0,
            "companies"."name" AS t1_r1,
            "companies"."category" AS t1_r2,
            "companies"."created_at" AS t1_r3,
            "companies"."updated_at" AS t1_r4
            FROM "employees"
            LEFT OUTER JOIN "companies" ON "companies"."id" = "employees"."company_id"
            WHERE (age < 80)
            AND "employees"."created_at" BETWEEN '#{dates.first}' AND '#{dates.last}'
            ORDER BY employees.id ASC NULLS LAST
            LIMIT 3
            OFFSET 0
          SQL
        end
        context 'today' do
          let(:created_at) { 'today' }
          let(:dates) { ['2020-03-15 06:00:00', '2020-03-16 05:59:59'] }
          it('to_sql') { expect(result.to_sql).to eq sql_query }
        end
        context 'yesterday' do
          let(:created_at) { 'yesterday' }
          let(:dates) { ['2020-03-14 06:00:00', '2020-03-15 05:59:59'] }
          it('to_sql') { expect(result.to_sql).to eq sql_query }
        end
        context 'last_7_days' do
          let(:created_at) { 'last_7_days' }
          let(:dates) { ['2020-03-09 06:00:00', '2020-03-16 05:59:59'] }
          it('to_sql') { expect(result.to_sql).to eq sql_query }
        end
        context 'last_30_days' do
          let(:created_at) { 'last_30_days' }
          let(:dates) { ['2020-02-15 07:00:00', '2020-03-16 05:59:59'] }
          it('to_sql') { expect(result.to_sql).to eq sql_query }
        end
        context 'this_month' do
          let(:created_at) { 'this_month' }
          let(:dates) { ['2020-03-01 07:00:00', '2020-03-16 05:59:59'] }
          it('to_sql') { expect(result.to_sql).to eq sql_query }
        end
        context 'last_month' do
          let(:created_at) { 'last_month' }
          let(:dates) { ['2020-02-01 07:00:00', '2020-03-01 06:59:59'] }
          it('to_sql') { expect(result.to_sql).to eq sql_query }
        end
        context 'last_3_months' do
          let(:created_at) { 'last_3_months' }
          let(:dates) { ['2019-12-17 07:00:00', '2020-03-16 05:59:59'] }
          it('to_sql') { expect(result.to_sql).to eq sql_query }
        end
      end
    end

    describe '#data' do
      context 'basic' do
        let!(:items) { second_employees }
        let(:params) { build_params sort_col: 'id', start: 1, length: 2 }
        let(:exp_result) do
          [
            { DT_RowId: emp4.id,
              id: emp4.id,
              username: 'emp4',
              full_name: 'Employee Cuatro',
              status: 'inactive',
              age: 23,
              hired_at: date2,
              created_at: date2,
              comment: 'emp04',
              company_name: 'Second Company',
              company_category: 'sandals',
              addresses_count: 'Office4, Main4' },
            { DT_RowId: emp5.id,
              id: emp5.id,
              username: 'emp5',
              full_name: 'Employee Cinco',
              status: 'active',
              age: 45,
              hired_at: date2,
              created_at: date2,
              comment: 'emp05',
              company_name: 'First Company',
              company_category: 'shoes',
              addresses_count: 'Office5, Main5' }
          ]
        end

        it('result') { expect(subject.data).to eq exp_result }
        it('result') { expect(subject.data).to eq exp_result }
      end
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
          addresses_count: 'office1|main1',
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
