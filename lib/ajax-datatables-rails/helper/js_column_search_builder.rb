# frozen_string_literal: true

module AjaxDatatablesRails
  module Helper
    class JsColumnSearchBuilder
      # @param [Column] column
      def self.build(column)
        new(column).build
      end

      # @param [Column] column
      def initialize(column)
        @column = column
      end

      FIELDS = [:title].freeze

      def build
        @column.to_hash(FIELDS).tap(&method(:build_search))
      end

      private

      def build_search(options)
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
    end
  end
end
