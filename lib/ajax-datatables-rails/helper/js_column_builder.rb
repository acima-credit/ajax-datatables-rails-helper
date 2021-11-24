# frozen_string_literal: true

module AjaxDatatablesRails
  module Helper
    class JsColumnBuilder
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

        display.each do |k, v|
          case k
          when :align
            options[:className] = "text-#{v}"
          else
            raise "unknown key [#{k}]"
          end
        end
      end
    end
  end
end
