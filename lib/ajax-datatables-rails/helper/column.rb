# frozen_string_literal: true

module AjaxDatatablesRails
  module Helper
    class Column
      def self.known_fields
        @known_fields ||= %i[field title source orderable searchable search display index].freeze
      end

      attr_accessor(*known_fields)

      def initialize(name, model, *args, **custom_options)
        update_defaults name
        update_basics name, model, args
        update_custom_options custom_options
        update_search
      end

      delegate :known_fields, to: :class

      def get(name)
        raise "unknown field [#{name}]" unless @known_fields.include?(name.to_sym)

        instance_variable_get "@#{name}"
      end

      alias [] get

      def set(name, value)
        raise "unknown field [#{name}]" unless known_fields.include?(name.to_sym)

        instance_variable_set "@#{name}", value
      end

      alias []= set

      def to_hash(fields = known_fields)
        fields.index_with { |k| send k }
      end

      def to_view_column
        ViewColumnBuilder.build self
      end

      def to_js_column
        JsColumnBuilder.build self
      end

      def to_js_search(params)
        JsColumnSearchBuilder.build self, params
      end

      def data?
        true
      end

      def inspect
        format '#<%s %s>',
               self.class.name,
               to_hash.compact.map { |k, v| format '%s=%s', k, v.inspect }.join(' ')
      end

      alias to_s inspect

      private

      def update_defaults(name)
        self.field = name
        self.searchable = false
        self.orderable = false
      end

      def update_basics(name, model, args)
        self.title ||= name.to_s.gsub(/_at$/, '').humanize
        self.source ||= format '%s.%s', model.name, field if model
        self.orderable = true if args.include?(:orderable)
      end

      def update_custom_options(custom_options)
        custom_options.each { |k, v| set k, v }
      end

      def update_search
        return if search.blank?

        self.searchable = true
        return unless search&.key?(:values)

        case search[:values].first
        when Numeric
          search[:cond] ||= :eq
        when String
          search[:cond] ||= :string_eq
        end
      end
    end

    class ActionColumn < Column
      def self.known_fields
        @known_fields ||= super.dup.push(:links).freeze
      end

      def self.build
        new :actions, nil
      end

      attr_reader :links

      def initialize(name, model, *args, **custom_options)
        super

        @field = nil
        @links = {}
      end

      def add_link(name, options = {})
        @links[name.to_sym] = options
      end

      def links_ary
        @links.each_with_object([]) { |(k, v), ary| ary.push v.update(name: k) }
      end

      def data?
        false
      end
    end
  end
end
