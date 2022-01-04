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

        def hooks
          @hooks ||= {
            get_raw_records: { before: [], after: [] },
            data: { before: [], before_each: [], after_each: [], after: [] }
          }
        end

        def add_hook(name, about, action = nil, &blk)
          action = blk if blk
          raise 'invalid action' unless action.is_a?(Symbol) || action.respond_to?(:call)

          section = hooks.dig name.to_sym, about
          return if section.any? { |x| x.to_s == action.to_s }

          section.push action
        end

        def before(name, action = nil, &blk)
          add_hook name, :before, action, &blk
        end

        def before_each(name, action = nil, &blk)
          add_hook name, :before_each, action, &blk
        end

        def after_each(name, action = nil, &blk)
          add_hook name, :after_each, action, &blk
        end

        def after(name, action = nil, &blk)
          add_hook name, :after, action, &blk
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
          @decorator = value.tap { |x| x.columns columns } unless value == :none
          @decorator ||= Class.new(::AjaxDatatablesRails::Helper::RowDecorator).tap do |decorator_class|
            decorator_class.datatable self
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

        def dummy_column(name, *args, **custom_options)
          columns[name.to_sym] = DummyColumn.new(name, model, *args, **custom_options)
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
        super filtered_params(params), options
      end

      delegate :model,
               :columns,
               :view_columns,
               :js_columns,
               :dom_id,
               :build_record_entry,
               :model_query,
               :hooks,
               to: :class

      def js_searches
        self.class.js_searches params
      end

      def base_scope
        model.unscoped
      end

      def get_raw_records
        scope = base_scope
        scope = run_hooks :get_raw_records, :before, scope

        changed = false
        changed, scope = update_scope_joins(changed, scope)
        changed, scope = update_scope_selects(changed, scope)
        scope.distinct if changed

        run_hooks :get_raw_records, :after, scope
      end

      def data
        rows = records
        rows = run_hooks :data, :before, rows
        rows = rows.map do |row|
          row = run_hooks :data, :before_each, row
          row = build_record_entry row
          run_hooks :data, :after_each, row
        end
        run_hooks :data, :after, rows
      end

      private

      def filtered_params(params)
        ParamsBuilder.build params, columns
      end

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

      def run_hooks(name, about, results)
        actions = hooks.dig name, about
        return results unless actions.present?

        actions.each do |action|
          if action.is_a?(Symbol)
            send action, results
          else
            action.call results
          end
        end

        results
      end
    end
  end
end
