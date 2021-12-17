# frozen_string_literal: true

module AjaxDatatablesRails
  module Helper
    class ViewColumnBuilder
      # @param [Column] column
      def self.build(column)
        new(column).build
      end

      # @param [Column] column
      def initialize(column)
        @column = column
      end

      FIELDS = %i[source title orderable searchable].freeze

      def build
        @column.to_hash(FIELDS).tap do |options|
          options[:cond] = @column.search[:cond] if @column.search&.dig(:cond)
          options[:delimiter] = @column.search[:delimiter] if @column.search&.dig(:delimiter)
        end
      end
    end
  end
end
