# frozen_string_literal: true

module AjaxDatatablesRails
  module Helper
    class JsValue
      def initialize(value)
        @value = value
      end

      def inspect(*_args)
        @value.to_s
      end

      alias to_s inspect
      alias to_json inspect
    end

    class JsColumnBuilder
      def self.transformations
        @transformations ||= {
          display: {
            align: ->(options, v) { options[:className] = "text-#{v}" },
            render: ->(options, v) { options[:render] = JsValue.new(v) }
          }
        }
      end

      # @param [Column] column
      def self.build(column)
        new(column).build
      end

      # @param [Column] column
      def initialize(column)
        @column = column
      end

      FIELDS = %i[title orderable searchable].freeze

      def build
        @column.to_hash(FIELDS).tap do |options|
          options[:data] = @column.field
          build_display options
        end
      end

      private

      def build_display(options)
        display = @column.display
        return if display.blank?

        display.each do |key, value|
          transformation = self.class.transformations[:display][key]
          raise "unknown key [#{key}]" unless transformation

          transformation.call options, value
        end
      end
    end
  end
end
