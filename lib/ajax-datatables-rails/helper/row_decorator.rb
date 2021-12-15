# frozen_string_literal: true

module AjaxDatatablesRails
  module Helper
    class RowDecorator
      def self.columns(value = :none)
        @columns = value unless value == :none
        @columns || []
      end

      def initialize(instance)
        @instance = instance
      end

      delegate :columns, to: :class

      def to_hash
        { DT_RowId: @instance.id }.tap do |hash|
          columns.each do |key, column|
            next unless column.data?

            hash_set key, column, hash
          end
        end
      end

      private

      def hash_set(key, value, hsh)
        new_key = key.to_s.tr('.', '_').to_sym
        new_value = get_value value
        hsh[new_key] = new_value
      end

      def get_value(column)
        %i[get_field_value get_full_field_value get_nested_field_value].each do |meth|
          res, value = send meth, column
          return value if res
        end
      end

      def get_field_value(column)
        return [false, nil] unless @instance.respond_to?(column.field)

        [true, @instance.send(column.field)]
      end

      def get_full_field_value(column)
        full_field = column.field.tr '.', '_'
        return [false, nil] unless @instance.respond_to?(full_field)

        [true, @instance.send(full_field)]
      end

      def get_nested_field_value(column)
        return [false, nil] unless column.related?

        value = @instance
        column.field.split('.').each do |name|
          return [true, nil] unless value.respond_to?(name)

          value = value.send name
        end
        [true, value]
      end
    end
  end
end
