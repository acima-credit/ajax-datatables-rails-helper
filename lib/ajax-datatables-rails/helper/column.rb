# frozen_string_literal: true

module AjaxDatatablesRails
  module Helper
    class Column
      def self.known_fields
        @known_fields ||= %i[field title source orderable searchable search display].freeze
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
        raise "unknown field [#{name}]" unless known_fields.include?(name.to_sym)

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

      def display?
        display != :none
      end

      def related?
        false
      end

      def inspect
        format '#<%s %s>',
               self.class.name,
               to_hash.compact.map { |k, v| format '%s=%s', k, v.inspect }.join(' ')
      end

      alias to_s inspect

      private

      def update_defaults(name)
        self.field ||= name
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
      class Link
        def initialize(name, options = {})
          @name = name
          @options = options
        end

        def to_hash
          {
            title: @options[:title],
            url: @options[:url]
          }.compact
        end
      end

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
        @links[name.to_sym] = Link.new(name, options).to_hash
      end

      def data?
        false
      end

      def display?
        true
      end
    end

    class RelatedColumn < Column
      def self.known_fields
        @known_fields ||= super.dup.push(:relation).freeze
      end

      attr_reader :base_model, :relation, :relation_key, :join_type, :joins, :includes, :references, :selects

      def initialize(name, base_model, relation, *args, **custom_options)
        super

        @base_model = base_model
        @relation = relation
        @relation_key = @relation.is_a?(String) ? @relation.to_sym : @relation
        @model = get_model_from base_model, relation
        @field = format '%s.%s', relation, name
        @source = format '%s.%s', @model, name
        add_association_queries args, custom_options
      end

      def update_model_query(datatable)
        %i[joins includes references selects].each do |type|
          send(type).each { |x| datatable.add_model_query type, x }
        end
      end

      def related?
        true
      end

      private

      def get_model_from(base_model, relation)
        current_model = base_model
        relation.to_s.split('.').each do |rel|
          found_model = current_model.reflect_on_association(rel)&.klass
          raise "could not find model for relation [#{rel}]" unless found_model

          current_model = found_model
        end
        current_model
      end

      def add_association_queries(args, custom_options)
        @join_type = get_join_type args, custom_options
        @joins = @join_type == :joins ? [relation_key] : []
        @includes = @join_type == :includes ? [relation_key] : []
        @references = custom_options[:references] || [relation_key]
        @selects = custom_options[:selects] || []
      end

      def get_join_type(args, opts)
        return opts[:type] if opts.key?(:type)

        if args.include?(:includes)
          :includes
        else
          :joins
        end
      end
    end
  end
end
