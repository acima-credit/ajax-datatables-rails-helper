# frozen_string_literal: true

module AjaxDatatablesRails
  module Helper
    module ExtendedDatatable
      def self.included(base)
        base.nulls_last = true
        base.extend ClassMethods
      end

      module ClassMethods
        def set_model(model)
          model = model.to_s if model.is_a?(Symbol)
          model = model.classify.constantize if model.is_a?(String)
          @model = model
        end

        def set_decorator(decorator)
          @decorator = decorator
        end

        attr_reader :decorator

        def default_model
          @default_model = name.gsub(/DataTable$/, '').constantize unless instance_variable_defined?(:@default_model)
          @default_model
        rescue NameError
          @default_model = nil
        end

        def model
          @model || default_model
        end

        def columns
          @columns ||= {}
        end

        def column(name, *args, **custom_options)
          columns[name.to_sym] = Column.new(name, model, *args, **custom_options)
        end

        def view_columns
          # columns.transform_values { |options| ViewColumnBuilder.build(options) }
          columns.transform_values(&:to_view_column)
        end

        def js_columns
          # columns.map { |k, v| JsColumnBuilder.build(k, v, view_columns[k]) }
          columns.values.map(&:to_js_column)
        end

        def js_searches(params)
          # columns.values.map { |v| JsColumnSearchBuilder.build(v) }
          columns.values.map do |column|
            column.to_js_search params
          end
        end

        def dom_id
          name.underscore.dasherize.tr('/', '-')
        end

        def build_record_entry(instance)
          return decorator.new(instance).to_hash if decorator.present?

          columns.
            transform_values { |v| instance.send(v.field) }.
            update(DT_RowId: instance.id)
        end
      end

      def initialize(params, options = {})
        super
      end

      delegate :model,
               :columns,
               :view_columns,
               :js_columns,
               :build_record_entry,
               to: :class

      def js_searches
        self.class.js_searches params
      end

      def get_raw_records
        model.unscoped
      end

      def data
        records.map { |row| build_record_entry row }
      end
    end
  end
end
