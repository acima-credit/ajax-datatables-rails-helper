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
  column 'created_at', :orderable
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
                        orderable: true, searchable: false, search: nil, display: nil }
        }
      end

      it('types') { expect(column_types).to eq ['AjaxDatatablesRails::Helper::Column'] }
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
          created_at: { source: "#{model.name}.created_at", title: 'Created', orderable: true, searchable: false }
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
          { title: 'Created', orderable: true, searchable: false, data: 'created_at' }
        ]
      end

      it('definition') { expect(subject.js_columns).to eq expected }
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
          { field: 'created_at', title: 'Created', type: 'none' }
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
            { field: 'created_at', title: 'Created', type: 'none' }
          ]
        end

        it('definition') { expect(subject.js_searches).to eq expected }
      end
    end

    describe '#get_raw_records' do
      it('definition') { expect(subject.get_raw_records).to be_a ActiveRecord::Relation }
      it('to_sql') { expect(subject.get_raw_records.to_sql).to eq 'SELECT "employees".* FROM "employees"' }
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
