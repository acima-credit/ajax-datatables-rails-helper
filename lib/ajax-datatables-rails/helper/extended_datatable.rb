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

        def model_query
          @model_query ||= { joins: [], includes: [], references: [], selects: [] }
        end

        def add_model_query(type, entry)
          sub_query = model_query[type]
          return if sub_query.include? entry

          sub_query << entry
        end

        def decorator(value = :none)
          @decorator = value unless value == :none
          @decorator ||= Class.new(::AjaxDatatablesRails::Helper::RowDecorator).tap do |x|
            x.columns columns
          end
        end

        def default_model
          @default_model ||= name.gsub(/DataTable$/, '').constantize
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

          sel_model = custom_options.delete(:model) || model
          columns[key] = Column.new(name, sel_model, *args, **custom_options)
        end

        def rel_column(relation, name, *args, **custom_options)
          key = format('%s.%s', relation, name).tr('.', '_').to_sym
          return if columns.key?(key)

          columns[key] = RelatedColumn.new(name, model, relation, *args, **custom_options).tap do |column|
            column.update_model_query self
          end
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
          decorator.new(instance).to_hash
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
               :model_query,
               to: :class

      def js_searches
        self.class.js_searches params
      end

      def base_scope
        model.unscoped
      end

      def get_raw_records
        base_scope.tap do |scope|
          changed = false
          changed, scope = update_scope_joins(changed, scope)
          changed, scope = update_scope_selects(changed, scope)
          scope.distinct if changed
        end
      end

      def data
        records.map { |row| build_record_entry row }
      end

      private

      def update_scope_joins(changed, scope)
        %i[joins includes references].each do |type|
          model_query[type].each do |value|
            scope = scope.send type, value
            changed = true
          end
        end
        [changed, scope]
      end

      def update_scope_selects(changed, scope)
        values = model_query[:selects].flatten.join(', ')
        unless values.blank?
          scope = scope.select values
          changed = true
        end
        [changed, scope]
      end
    end
  end
end
