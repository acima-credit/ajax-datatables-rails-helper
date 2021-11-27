# frozen_string_literal: true

module AjaxDatatablesRails
  module Helper
    class JsColumnSearchBuilder
      # @param [Column] column
      def self.build(column, params)
        new(column, params).build
      end

      # @param [Column] column
      def initialize(column, params)
        @column = column
        @params = params
      end

      FIELDS = %i[field title].freeze

      def build
        @column.to_hash(FIELDS).tap do |options|
          build_search_options options
          build_search_value options
        end
      end

      private

      def build_search_options(options)
        search = @column.search

        if search.nil?
          options[:type] = 'none'
        elsif search[:values]
          options[:type] = 'select'
          options[:values] = search[:values]
        else
          options[:type] = 'text'
        end
      end

      def build_search_value(options)
        value = @params[@column.field]
        return unless value.present?

        options[:value] = value
      end
    end
  end
end
