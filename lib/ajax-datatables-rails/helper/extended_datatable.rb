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
          key = name.to_sym
          return if columns.key?(key)

          columns[key] = Column.new(name, model, *args, **custom_options)
        end

        def action_link(name, **options)
          add_action_column
          action_column.add_link name, options
        end

        def action_column
          columns[:actions]
        end

        def add_action_column
          return if action_column

          columns[:actions] = ActionColumn.build
        end

        def view_columns
          columns.transform_values(&:to_view_column)
        end

        def js_columns
          columns.values.select(&:display?).map(&:to_js_column)
        end

        def js_searches(params)
          columns.values.select(&:display?).map { |column| column.to_js_search params }
        end

        def dom_id
          name.underscore.dasherize.tr('/', '-')
        end

        def build_record_entry(instance)
          return decorator.new(instance).to_hash if decorator.present?

          columns.
            select { |_k, v| v.data? }.
            transform_values { |v| instance.respond_to?(v.field) ? instance.send(v.field) : nil }.
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
               :dom_id,
               :build_record_entry,
               to: :class

      def js_searches
        self.class.js_searches params
      end

      def get_raw_records
        model.unscoped
      end

      def additional_data
        {}
      end

      def data
        records.map { |row| build_record_entry row }
      end
    end
  end
end
